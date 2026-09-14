import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/router.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/core/error/retry_policy.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/core/location/location_service.dart';
import 'package:foodloop/features/auth/domain/account.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';
import 'package:foodloop/features/auth/domain/auth_repository.dart';
import 'package:foodloop/features/auth/presentation/auth_providers.dart';
import 'package:foodloop/features/home/presentation/home_screen.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_location_cache.dart';

Position _position({double latitude = 11.112, double longitude = 78.006}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// A location service whose answer a test can change between attempts, and
/// which counts how many times it was asked.
class _SwitchableLocation implements LocationService {
  _SwitchableLocation(this.result);

  LocationResult result;
  int requestCalls = 0;

  @override
  Future<LocationResult> requestLocation() async {
    requestCalls++;
    return result;
  }

  @override
  Future<LocationReadiness> readiness() async => LocationReadiness.unknown;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}

class _CountingListings implements ListingRepository {
  int nearbyCalls = 0;
  List<FoodListing> results = const [];
  Failure? failWith;

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
    if (failWith != null) throw failWith!;
    return results;
  }

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _EmptyRescues implements RescueRepository {
  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _SignedIn implements AuthRepository {
  @override
  Future<Account?> restoreSession() async => Account(
    id: 'u1',
    email: 'asha@example.com',
    fullName: 'Asha Rao',
    role: AccountRole.consumer,
    status: AccountStatus.active,
    emailVerified: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

FoodListing _listing() => const FoodListing(
  id: 'l1',
  title: '25 Meal Boxes',
  category: 'Vegetarian',
  distanceKm: 1.4,
  imageAsset: 'assets/images/food_meal_boxes.jpg',
  urgency: ListingUrgency.available,
  servings: 25,
  pickupWindow: 'Today, 7:30 PM – 8:30 PM',
  pickupLocation: 'Community Hall',
  latitude: 11.113,
  longitude: 78.007,
  sharedBy: 'Asha Rao',
  description: 'Fresh.',
  tags: [],
);

void main() {
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/PlusJakartaSans[wght].ttf',
    ).readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  late _CountingListings listings;
  late _SwitchableLocation location;
  late FakeLocationCache cache;

  setUp(() {
    listings = _CountingListings();
    // The long-absence case: nothing remembered, and the device refuses.
    location = _SwitchableLocation(
      const LocationResult(LocationOutcome.denied),
    );
    cache = FakeLocationCache();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<GoRouter> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      // The app's real policy, not a test-only one: this file is partly a test
      // *of* that policy, and Riverpod's default would retry
      // `LocationUnavailable` ten times over.
      retry: foodloopRetry,
      overrides: [
        authRepositoryProvider.overrideWithValue(_SignedIn()),
        listingRepositoryProvider.overrideWithValue(listings),
        rescueRepositoryProvider.overrideWithValue(_EmptyRescues()),
        locationCacheProvider.overrideWithValue(cache),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2000));
    await settle(tester);
    return router;
  }

  group('the reported failure: back after a long time', () {
    testWidgets('Home renders even with no location and no listings', (
      tester,
    ) async {
      await pumpHome(tester);

      // The whole point: one failed dependency must not take the page.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Rescue food'), findsWidgets);
      expect(find.text('Give food'), findsWidgets);
    });

    testWidgets('it says location is the problem, not the food query', (
      tester,
    ) async {
      await pumpHome(tester);

      // "Couldn't load nearby food" is a lie when nobody knows where the user
      // is, and it points them at a retry that cannot help.
      expect(find.text('Location is unavailable'), findsOneWidget);
      expect(find.text('Turn on location to see food near you.'), findsOneWidget);
      expect(find.text("Couldn't load nearby food"), findsNothing);
    });

    testWidgets('no request was made without somewhere to search from', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(listings.nearbyCalls, 0);
    });

    testWidgets('and it does not spin forever', (tester) async {
      await pumpHome(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Enable location recovers — the bug that made retry dead', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.text('Location is unavailable'), findsOneWidget);

      // The permission is granted; the user presses the button.
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.results = [_listing()];

      await tester.ensureVisible(find.text('Enable location').last);
      await tester.pump();
      await tester.tap(find.text('Enable location').last);
      await settle(tester);

      // Before the fix this recomputed from a `LocationUnavailable` cached on
      // a provider that is never disposed, so no request ever left the device
      // and the only cure was killing the app.
      expect(location.requestCalls, greaterThan(1));
      expect(listings.nearbyCalls, 1);
      expect(find.text('Location is unavailable'), findsNothing);
      expect(find.text('25 Meal Boxes'), findsWidgets);
    });

    testWidgets('recovering asks for the listings exactly once', (
      tester,
    ) async {
      await pumpHome(tester);

      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      await tester.ensureVisible(find.text('Enable location').last);
      await tester.pump();
      await tester.tap(find.text('Enable location').last);
      await settle(tester);
      await settle(tester);

      // One location, one query. A recovery that storms the backend is not a
      // recovery.
      expect(listings.nearbyCalls, 1);
    });
  });

  group('the map is not hostage to the listings API', () {
    testWidgets('a failed nearby query leaves the map and the page alone', (
      tester,
    ) async {
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.failWith = const NetworkFailure();

      await pumpHome(tester);

      // The map only ever needed a location, which it has.
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      // And the failure is reported where it happened.
      expect(find.text("Couldn't load nearby food"), findsOneWidget);
      expect(find.text('Try again'), findsWidgets);
    });

    testWidgets('zero listings still shows the real map', (tester) async {
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.results = const [];

      await pumpHome(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Nothing to rescue right now'), findsOneWidget);
    });

    testWidgets('with no location the card offers the action, not a lie', (
      tester,
    ) async {
      await pumpHome(tester);

      // No real map is drawn on a position nobody has.
      expect(find.byType(FlutterMap), findsNothing);
      // And it does not claim a nearest distance it cannot know.
      expect(find.text('Location needed'), findsOneWidget);
      expect(find.textContaining('Nearest:'), findsNothing);
    });

    testWidgets('retrying a failed query does not re-ask for location', (
      tester,
    ) async {
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.failWith = const NetworkFailure();

      await pumpHome(tester);
      final locationCallsBefore = location.requestCalls;
      listings.failWith = null;
      listings.results = [_listing()];

      await tester.ensureVisible(find.text('Try again').first);
      await tester.pump();
      await tester.tap(find.text('Try again').first);
      await settle(tester);

      expect(find.text('25 Meal Boxes'), findsWidgets);
      // The remembered fix is reused, so recovering from a network blip does
      // not drag the user through the permission flow again.
      expect(location.requestCalls, locationCallsBefore);
    });
  });

  group('one query per launch', () {
    testWidgets('Home asks once, not once per rebuild', (tester) async {
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.results = [_listing()];

      await pumpHome(tester);
      await settle(tester);
      await settle(tester);

      expect(listings.nearbyCalls, 1);
      expect(location.requestCalls, 1);
    });

    testWidgets('opening Explore reuses it', (tester) async {
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.results = [_listing()];

      final router = await pumpHome(tester);
      expect(listings.nearbyCalls, 1);

      router.go(AppRoutes.explore);
      await settle(tester);

      // Explore's default chip asks the server exactly what Home asked.
      expect(listings.nearbyCalls, 1);
    });

    testWidgets('Home -> Explore -> Home is not a request storm', (
      tester,
    ) async {
      location.result = LocationResult(
        LocationOutcome.granted,
        position: _position(),
      );
      listings.results = [_listing()];

      final router = await pumpHome(tester);
      router.go(AppRoutes.explore);
      await settle(tester);
      router.go(AppRoutes.home);
      await settle(tester);
      router.go(AppRoutes.profile);
      await settle(tester);
      router.go(AppRoutes.home);
      await settle(tester);

      expect(listings.nearbyCalls, 1);
      expect(location.requestCalls, 1);
    });
  });
}
