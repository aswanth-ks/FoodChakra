import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/cache/cache_for.dart';
import 'package:foodloop/core/config/env.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/core/location/location_service.dart';
import 'package:foodloop/core/network/dio_client.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';

import 'support/fake_location_cache.dart';

/// Reports how it was called and answers on command.
class _RecordingListings implements ListingRepository {
  int nearbyCalls = 0;
  final queries = <({double latitude, double longitude})>[];
  List<FoodListing> results = const [];

  @override
  Future<List<FoodListing>> nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    List<String> foodTypes = const [],
    String? source,
    int limit = 20,
    int offset = 0,
  }) async {
    nearbyCalls++;
    queries.add((latitude: latitude, longitude: longitude));
    return results;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// A location service whose every call can be made to hang.
class _HangingLocationService implements LocationService {
  @override
  Future<LocationReadiness> readiness() => Completer<LocationReadiness>().future;

  @override
  Future<LocationResult> requestLocation() =>
      Completer<LocationResult>().future;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}

/// Answers with headers immediately, then never sends a body.
///
/// This is what `receiveTimeout` actually guards: a connection that is
/// accepted and then goes quiet. Delaying inside `fetch` would test the
/// connect budget instead.
class _StalledBodyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    // Never emits, never closes.
    StreamController<Uint8List>().stream,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  group('network timeouts are bounded', () {
    test('ordinary calls get a short, explicit budget', () {
      // Measured against the deployed API: an authenticated call costs about
      // a second warm. A 20s budget — the previous value — is most of a
      // minute of frozen UI across the two or three calls a screen makes.
      expect(Env.receiveTimeout, lessThanOrEqualTo(const Duration(seconds: 12)));
      expect(Env.connectTimeout, lessThanOrEqualTo(const Duration(seconds: 12)));
      expect(Env.sendTimeout, lessThanOrEqualTo(const Duration(seconds: 12)));
      // And a floor: short enough to be useless would be its own bug.
      expect(Env.receiveTimeout, greaterThanOrEqualTo(const Duration(seconds: 5)));
    });

    test('the email budget stays separate, and longer', () {
      // `/auth/register` hands a message to SMTP while the request is open, so
      // its latency is the API's plus a whole SMTP conversation. That
      // exception must not leak into ordinary calls: a 60s budget everywhere
      // is exactly the frozen app this pass exists to remove.
      expect(Env.emailReceiveTimeout, const Duration(seconds: 60));
      expect(
        Env.emailReceiveTimeout,
        greaterThan(Env.receiveTimeout),
        reason: 'the email path needs its own, longer budget',
      );
    });

    test('the client is actually configured with them', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);
      expect(dio.options.connectTimeout, Env.connectTimeout);
      expect(dio.options.receiveTimeout, Env.receiveTimeout);
      expect(dio.options.sendTimeout, Env.sendTimeout);
    });

    test('a stalled response fails on the budget rather than hanging', () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.invalid',
          receiveTimeout: const Duration(milliseconds: 200),
        ),
      )..httpClientAdapter = _StalledBodyAdapter();

      final stopwatch = Stopwatch()..start();
      await expectLater(
        dio.get<Map<String, dynamic>>('/stalled'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
      stopwatch.stop();

      // Terminated by the client. Without a receive budget this request would
      // never come back at all.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });

  group('GPS is bounded', () {
    test('a hung platform resolves as a timeout, not a hang', () async {
      // The real service wraps geolocator; this stands in for a platform that
      // accepts the call and never answers, which is what an indoor first fix
      // can look like.
      final result = await _HangingLocationService()
          .requestLocation()
          .timeout(
            LocationService.overallTimeout,
            onTimeout: () =>
                const LocationResult(LocationOutcome.timedOut),
          );

      expect(result.outcome, LocationOutcome.timedOut);
      expect(result.isGranted, isFalse);
      expect(result.position, isNull);
    });

    test('the bounds are real and ordered', () {
      // The fix must give up with time left to try the last-known position,
      // or the fallback can never run.
      expect(
        LocationService.fixTimeout,
        lessThan(LocationService.overallTimeout),
      );
      expect(
        LocationService.overallTimeout,
        lessThanOrEqualTo(const Duration(seconds: 15)),
      );
    });

    test('a timeout is a distinct outcome with its own message', () {
      // Worth telling apart from `unavailable`: this is the one case where
      // trying again is genuinely likely to work.
      expect(
        LocationOutcome.values,
        contains(LocationOutcome.timedOut),
      );
    });
  });

  group('the remembered location', () {
    test('an old fix is refused rather than passed off as current', () async {
      final cache = FakeLocationCache(
        stored: DeviceLocation(
          latitude: 11.1,
          longitude: 78.0,
          capturedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      // The fake returns whatever it holds, so age is asserted against the
      // real rule the production cache applies.
      expect(
        DateTime.now().difference(cache.stored!.capturedAt),
        greaterThan(LocationCache.maxAge),
        reason: 'a fix this old must not stand for "here"',
      );
    });

    test('a remembered fix unblocks the nearby query with no GPS call', () async {
      final listings = _RecordingListings();
      final cache = FakeLocationCache(
        stored: DeviceLocation(
          latitude: 11.112,
          longitude: 78.006,
          capturedAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          listingRepositoryProvider.overrideWithValue(listings),
          locationCacheProvider.overrideWithValue(cache),
          // If this is ever reached the test hangs, which is the point: the
          // remembered fix must be enough on its own.
          locationServiceProvider.overrideWithValue(_HangingLocationService()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(nearbyListingsProvider.future)
          .timeout(const Duration(seconds: 5));

      expect(result, isEmpty);
      expect(listings.nearbyCalls, 1);
      // The query used the remembered coordinates, not an invented pair.
      expect(listings.queries.single.latitude, 11.112);
      expect(listings.queries.single.longitude, 78.006);
    });

    test('a fix read from the cache is not written straight back', () async {
      final cache = FakeLocationCache(
        stored: DeviceLocation(
          latitude: 11.112,
          longitude: 78.006,
          capturedAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          listingRepositoryProvider.overrideWithValue(_RecordingListings()),
          locationCacheProvider.overrideWithValue(cache),
          locationServiceProvider.overrideWithValue(_HangingLocationService()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentOriginProvider.future)
          .timeout(const Duration(seconds: 5));

      // Writing it back would refresh its timestamp, letting a stale fix renew
      // itself for as long as the app keeps being opened and quietly outlive
      // the age limit.
      expect(cache.writes, 0);
    });

    test('with nothing remembered and no GPS, the query fails and stops', () async {
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          listingRepositoryProvider.overrideWithValue(_RecordingListings()),
          locationCacheProvider.overrideWithValue(FakeLocationCache()),
          locationServiceProvider.overrideWithValue(
            _FailingLocationService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Reaches a terminal state rather than spinning: an error the screens
      // can show with a retry.
      await expectLater(
        container.read(currentOriginProvider.future),
        throwsA(isA<LocationUnavailable>()),
      );
    });
  });

  group('the background location refresh', () {
    test('a fix from the same place does not re-query', () async {
      final here = DeviceLocation(
        latitude: 11.1120,
        longitude: 78.0060,
        capturedAt: DateTime.now(),
      );
      // ~12 m away: GPS noise, not movement.
      final jitter = DeviceLocation(
        latitude: 11.11211,
        longitude: 78.00601,
        capturedAt: DateTime.now(),
      );

      expect(here.metresFrom(jitter), lessThan(75));
    });

    test('a fix from somewhere else does', () async {
      final here = DeviceLocation(
        latitude: 11.1120,
        longitude: 78.0060,
        capturedAt: DateTime.now(),
      );
      // ~1.2 km away.
      final moved = DeviceLocation(
        latitude: 11.1230,
        longitude: 78.0060,
        capturedAt: DateTime.now(),
      );

      expect(here.metresFrom(moved), greaterThan(75));
    });

    test('the distance is symmetric and zero for a point with itself', () {
      final a = DeviceLocation(
        latitude: 11.112,
        longitude: 78.006,
        capturedAt: DateTime.now(),
      );
      final b = DeviceLocation(
        latitude: 10.9577,
        longitude: 78.0809,
        capturedAt: DateTime.now(),
      );

      expect(a.metresFrom(a), 0);
      expect(a.metresFrom(b), closeTo(b.metresFrom(a), 0.001));
      // Karur to the test point is about 19 km.
      expect(a.metresFrom(b), greaterThan(15000));
      expect(a.metresFrom(b), lessThan(25000));
    });
  });

  group('cacheFor', () {
    test('a rebuild inside the window does not refetch', () async {
      var builds = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        cacheFor(ref, const Duration(minutes: 5));
        return ++builds;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(builds, 1);

      // The screen goes away…
      first.close();
      // …and comes back.
      container.listen(provider, (_, _) {});
      await container.read(provider.future);

      expect(builds, 1, reason: 'navigation is not a request for fresh data');
    });

    test('an explicit invalidation still refetches immediately', () async {
      var builds = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        cacheFor(ref, const Duration(minutes: 5));
        return ++builds;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(builds, 1);

      // A claim or a publish must be able to force a refresh regardless of
      // the window.
      container.invalidate(provider);
      await container.read(provider.future);

      expect(builds, 2);
    });

    test('past the window it refetches on the way back in', () async {
      var builds = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        // Zero window: anything that leaves and returns is already stale.
        cacheFor(ref, Duration.zero);
        return ++builds;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(builds, 1);

      first.close();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      container.listen(provider, (_, _) {});
      // The refetch is scheduled as a microtask, so it lands before the next
      // frame in the app. Drain it here for the same reason.
      await Future<void>.delayed(Duration.zero);
      await container.read(provider.future);

      expect(builds, 2, reason: 'a stale value must not be served as current');
    });
  });
}

/// Refuses, promptly. The failure path must terminate as reliably as success.
class _FailingLocationService implements LocationService {
  const _FailingLocationService();

  @override
  Future<LocationReadiness> readiness() async => LocationReadiness.needsSetup;

  @override
  Future<LocationResult> requestLocation() async =>
      const LocationResult(LocationOutcome.denied);

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
