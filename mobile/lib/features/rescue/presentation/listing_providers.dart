import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_for.dart';
import '../../../core/diagnostics/perf_trace.dart';
import '../../../core/location/location_cache.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/network/dio_client.dart';
import '../data/listing_repository_impl.dart';
import '../domain/food_listing.dart';
import '../domain/listing_repository.dart';

/// Binds the repository interface to its implementation.
///
/// Tests override this with a fake, which is why the screens only ever see the
/// interface.
final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ListingRepositoryImpl(ref.watch(dioProvider)),
);

/// Where "near me" is measured from.
///
/// Resolved in three steps, cheapest first:
///
/// 1. the fix already held in memory for this session;
/// 2. the fix remembered from a previous launch, which unblocks the first
///    request immediately and is refreshed in the background;
/// 3. a real request to the device.
///
/// Step 2 is what makes a cold start fast. Without it every launch waited on a
/// full permission-plus-GPS round trip before the nearby query could even be
/// sent, so the whole of Home's content sat behind the slowest thing on the
/// phone. A fix from minutes ago is a real reading, and [LocationCache] throws
/// away anything old enough to be misleading.
///
/// There is still no fallback coordinate. A stand-in origin used to be
/// returned when the device would not give a position, which quietly answered
/// "food near you" with food near somewhere else entirely — wrong distances,
/// wrong pickups, and no sign to the user that anything was amiss. Failing
/// here instead lets the screens show their error state and offer a retry.
final currentOriginProvider =
    FutureProvider<({double latitude, double longitude})>((ref) async {
      final stored = ref.watch(deviceLocationProvider);
      if (stored != null) {
        return (latitude: stored.latitude, longitude: stored.longitude);
      }

      final cached = await ref.read(locationCacheProvider).read();
      if (cached != null) {
        // Returned directly, and deliberately *not* written into
        // `deviceLocationProvider` here: this provider watches that one, so
        // publishing mid-build would invalidate the very computation the
        // caller is awaiting and could leave it hanging — the infinite wait
        // this pass exists to remove. The background refresh below publishes
        // the real fix instead, which recomputes this cleanly.
        // Compared against the fix actually in use. It is deliberately not
        // published to `deviceLocationProvider` (see above), so the refresh
        // cannot read it back from there.
        unawaited(_refreshLocationInBackground(ref, inUse: cached));
        return (latitude: cached.latitude, longitude: cached.longitude);
      }

      final result = await ref.read(locationServiceProvider).requestLocation();
      final position = result.position;
      if (!result.isGranted || position == null) {
        throw const LocationUnavailable();
      }

      // Remembered, so the rest of the session — and the next launch — works
      // from one known origin rather than asking the platform again.
      ref.read(deviceLocationProvider.notifier).setFromPosition(position);
      return (latitude: position.latitude, longitude: position.longitude);
    });

/// How far the user must actually have moved for a fresh fix to be worth
/// acting on.
///
/// Below this, the nearby answer cannot meaningfully change — the search runs
/// in kilometres — so republishing the origin would buy a second round trip
/// and an identical list. Measured on device: a cold start with a remembered
/// fix issued `/listings/nearby` twice, 30ms apart, for coordinates that were
/// the same street corner.
const double _movedEnoughMetres = 75;

/// Takes a fresh fix without anyone waiting on it.
///
/// The screen is already showing results from the remembered position. If the
/// new reading says the user is somewhere else, it is published and the list
/// quietly corrects itself; if it says they are where we thought, only the
/// stored copy is refreshed, so the cache stays young without costing a query.
///
/// A failure is swallowed on purpose: the user has real data on screen and
/// does not need to be told that an invisible refresh they never asked for did
/// not happen.
Future<void> _refreshLocationInBackground(
  Ref ref, {
  required DeviceLocation inUse,
}) async {
  try {
    final result = await ref.read(locationServiceProvider).requestLocation();
    final position = result.position;
    if (!result.isGranted || position == null) return;

    final fresh = DeviceLocation.fromPosition(position);
    final current = ref.read(deviceLocationProvider) ?? inUse;

    if (current.metresFrom(fresh) < _movedEnoughMetres) {
      // Same place. Remember the newer reading so the stored fix does not age
      // out, but do not republish it: nothing downstream would change except
      // the number of requests.
      await ref.read(locationCacheProvider).write(fresh);
      return;
    }

    ref.read(deviceLocationProvider.notifier).set(fresh);
  } catch (_) {
    // Nothing to report: the cached origin still stands.
  }
}

/// Re-runs the nearby query from scratch, location included.
///
/// This exists because "Try again" used to be a dead button. The nearby query
/// depends on [currentOriginProvider], which is not `autoDispose` and so keeps
/// its value — including its *error* — for the life of the app. Once a
/// location attempt failed, invalidating only the listings provider recomputed
/// it from that same cached `LocationUnavailable` and failed again instantly,
/// with no request ever reaching the network. The only way out was to kill the
/// app.
///
/// Dropping the origin first is what makes the retry real: the location is
/// resolved again (memory, then the remembered fix, then the device), and only
/// then is the listings query re-run.
extension NearbyRefresh on WidgetRef {
  void refreshNearbyFood() {
    invalidate(currentOriginProvider);
    invalidate(nearbyListingsProvider);
  }
}

/// Claimable surplus near the device. Backs Home.
final nearbyListingsProvider = FutureProvider.autoDispose<List<FoodListing>>((
  ref,
) async {
  // Held briefly after the last listener goes, so Home -> Explore -> Home does
  // not refetch what it read a moment ago. Short enough that returning to Home
  // minutes later still asks the server.
  cacheFor(ref, const Duration(seconds: 45));
  final origin = await PerfTrace.span(
    'currentOrigin (location resolved)',
    () => ref.watch(currentOriginProvider.future),
  );
  return PerfTrace.span(
    'nearby listings',
    () => ref
        .watch(listingRepositoryProvider)
        .nearby(latitude: origin.latitude, longitude: origin.longitude),
  );
});

/// The chip Explore opens on, which asks for the same thing Home does.
///
/// Kept next to the provider that special-cases it rather than reaching into
/// `ExploreScreen.filters`, so the presentation layer is not a dependency of
/// the data layer.
const String _defaultFilter = 'Nearby';

/// Explore, with its chip applied.
///
/// Two kinds of filter, and the difference is worth being explicit about:
///
/// * **Vegetarian, Vegan, Event food** narrow the query itself, through the
///   `food_type` and `source` parameters the API supports.
/// * **Ready now, Expiring soon** filter the returned page on `urgency`, which
///   the server computes per request from the pickup window. There is no query
///   parameter for it — urgency is derived, never stored — so this narrows
///   what came back rather than what was asked for. With the current page size
///   that is the whole nearby set; it would need a server-side filter before
///   Explore paginates.
/// * **Nearby** is the default ordering, which `$nearSphere` already provides.
final exploreListingsProvider = FutureProvider.autoDispose
    .family<List<FoodListing>, String>((ref, filter) async {
      // Flipping between chips and back is navigation, not a request for
      // fresher data.
      cacheFor(ref, const Duration(seconds: 45));

      // The default chip asks the server exactly what Home already asked:
      // nearest-first, no food type, no source. Measured on device, opening
      // Explore from Home spent 1054ms re-fetching a list the previous screen
      // was already showing. Sharing the provider makes that free, and keeps
      // the two screens from disagreeing about what is nearby.
      if (filter == _defaultFilter) {
        return ref.watch(nearbyListingsProvider.future);
      }

      final origin = await ref.watch(currentOriginProvider.future);
      final listings = await ref
          .watch(listingRepositoryProvider)
          .nearby(
            latitude: origin.latitude,
            longitude: origin.longitude,
            foodTypes: switch (filter) {
              'Vegetarian' => const ['vegetarian'],
              'Vegan' => const ['vegan'],
              _ => const [],
            },
            source: filter == 'Event food' ? 'event' : null,
          );

      return switch (filter) {
        'Ready now' => listings
            .where((l) => l.urgency != ListingUrgency.scheduled)
            .toList(growable: false),
        'Expiring soon' => listings
            .where(
              (l) =>
                  l.urgency == ListingUrgency.expiring ||
                  l.urgency == ListingUrgency.critical,
            )
            .toList(growable: false),
        _ => listings,
      };
    });

/// One listing, for the Food Details screen.
final listingDetailProvider = FutureProvider.autoDispose
    .family<FoodListing, String>((ref, id) {
      return ref.watch(listingRepositoryProvider).byId(id);
    });

/// The signed-in account's own listings. Backs Activity and Partner Surplus.
final myListingsProvider = FutureProvider.autoDispose<List<FoodListing>>((ref) {
  // Read by Activity, Impact and Profile. Without a grace window, moving
  // between those three tabs refetches the same list each time.
  cacheFor(ref, const Duration(seconds: 45));
  return ref.watch(listingRepositoryProvider).mine();
});
