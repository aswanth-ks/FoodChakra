import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
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

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

/// Where "near me" is measured from.
///
/// Falls back to the locality the designs use when the device will not give a
/// position. Explore showing the wrong neighbourhood is a far better failure
/// than Explore showing nothing at all — and the fallback is only ever a
/// query origin, never something written to a listing.
const _fallbackOrigin = (latitude: 10.9577, longitude: 78.0809);

final currentOriginProvider =
    FutureProvider<({double latitude, double longitude})>((ref) async {
      final result = await ref.watch(locationServiceProvider).requestLocation();
      final position = result.position;
      if (!result.isGranted || position == null) return _fallbackOrigin;
      return (latitude: position.latitude, longitude: position.longitude);
    });

/// Claimable surplus near the device. Backs Home.
final nearbyListingsProvider = FutureProvider.autoDispose<List<FoodListing>>((
  ref,
) async {
  final origin = await ref.watch(currentOriginProvider.future);
  return ref
      .watch(listingRepositoryProvider)
      .nearby(latitude: origin.latitude, longitude: origin.longitude);
});

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
  return ref.watch(listingRepositoryProvider).mine();
});
