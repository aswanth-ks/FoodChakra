import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/router.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
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
import 'package:foodloop/core/location/location_cache.dart';

import 'support/fake_location_cache.dart';

Account account() => Account(
  id: 'u1',
  email: 'asha@example.com',
  fullName: 'Asha Rao',
  role: AccountRole.consumer,
  status: AccountStatus.active,
  emailVerified: true,
);

FoodListing listing({String id = 'l1', String title = '25 Meal Boxes'}) =>
    FoodListing(
      id: id,
      title: title,
      category: 'Vegetarian',
      distanceKm: 1.4,
      imageAsset: 'assets/images/food_meal_boxes.jpg',
      urgency: ListingUrgency.available,
      servings: 25,
      pickupWindow: 'Today, 7:30 PM – 8:30 PM',
      pickupLocation: 'Community Hall',
      pickupLocality: 'Karur, Tamil Nadu',
      sharedBy: 'Asha Rao',
      description: 'Freshly prepared.',
      tags: const [],
    );

class FakeAuth implements AuthRepository {
  @override
  Future<Account?> restoreSession() async => account();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
  /// Not exercised by this file. A stub rather than a fake, so a test that
  /// reaches it fails loudly instead of quietly passing.
  @override
  Future<Account> updateProfile({required String fullName}) =>
      throw UnimplementedError('updateProfile is not used in this test');

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError('changePassword is not used in this test');

}

/// Counts calls so a test can prove Home is not asking twice, and can hold a
/// response open to observe the loading state.
class CountingListings implements ListingRepository {
  CountingListings({this.results = const []});

  List<FoodListing> results;
  Failure? failWith;
  int nearbyCalls = 0;
  Completer<void>? gate;

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
    if (gate != null) await gate!.future;
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

class EmptyRescues implements RescueRepository {
  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// Counts platform location calls, to prove rebuilds do not re-ask the GPS.
class CountingLocation implements LocationService {
  int requestCalls = 0;

  @override
  Future<LocationReadiness> readiness() async => LocationReadiness.ready;

  @override
  Future<LocationResult> requestLocation() async {
    requestCalls++;
    return LocationResult(
      LocationOutcome.granted,
      position: Position(
        latitude: 10.9,
        longitude: 78.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/PlusJakartaSans[wght].ttf',
    ).readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  late CountingListings listings;
  late CountingLocation location;

  setUp(() {
    listings = CountingListings();
    location = CountingLocation();
  });

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    DeviceLocation? storedFix,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        authRepositoryProvider.overrideWithValue(FakeAuth()),
        listingRepositoryProvider.overrideWithValue(listings),
        rescueRepositoryProvider.overrideWithValue(EmptyRescues()),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);

    // Seeded before anything reads the origin, which is the real sequence:
    // the location gate stores the fix on the way to Home.
    if (storedFix != null) {
      container.read(deviceLocationProvider.notifier).set(storedFix);
    }

    final router = container.read(routerProvider);
    router.go('/home');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the shell renders while nearby food is still loading', (
    tester,
  ) async {
    listings.gate = Completer<void>();

    await pumpHome(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The page itself is up, not a full-screen spinner.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.text('Rescue food'), findsOneWidget);
    expect(find.text('Give food'), findsOneWidget);
    expect(find.text('Your impact'), findsOneWidget);
    // Only the nearby section is pending.
    expect(find.bySemanticsLabel('Loading nearby food'), findsWidgets);

    listings.gate!.complete();
    await settle(tester);
  });

  testWidgets('zero listings shows an empty state, not a spinner', (
    tester,
  ) async {
    listings.results = const [];

    await pumpHome(tester);
    await settle(tester);

    expect(find.text('Nothing to rescue right now'), findsOneWidget);
    expect(
      find.text(
        'No surplus food is available nearby yet. Check back a little later.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Loading nearby food'), findsNothing);
    expect(find.text('Nothing nearby right now'), findsOneWidget);
  });

  testWidgets('real listings render once they arrive', (tester) async {
    listings.results = [listing(), listing(id: 'l2', title: '10 Sandwiches')];

    await pumpHome(tester);
    await settle(tester);

    expect(find.text('25 Meal Boxes'), findsOneWidget);
    expect(find.text('10 Sandwiches'), findsOneWidget);
    expect(find.text('Nothing to rescue right now'), findsNothing);
  });

  testWidgets('a failed nearby query shows a section error, page intact', (
    tester,
  ) async {
    listings.failWith = const NetworkFailure();

    await pumpHome(tester);
    await settle(tester);

    // The section reports the failure...
    expect(find.text("Couldn't load nearby food"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // ...and the rest of Home is still there.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.text('Your impact'), findsOneWidget);
  });

  testWidgets('Try again re-queries the backend', (tester) async {
    listings.failWith = const NetworkFailure();

    await pumpHome(tester);
    await settle(tester);
    final before = listings.nearbyCalls;

    listings.failWith = null;
    listings.results = [listing()];
    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(listings.nearbyCalls, greaterThan(before));
    expect(find.text('25 Meal Boxes'), findsOneWidget);
  });

  testWidgets('the GPS is asked at most once, not on every rebuild', (
    tester,
  ) async {
    listings.results = [listing()];

    await pumpHome(tester);
    await settle(tester);

    final afterFirstLoad = location.requestCalls;
    expect(afterFirstLoad, lessThanOrEqualTo(1));

    // Several more frames must not produce more platform calls.
    await settle(tester);
    await settle(tester);
    expect(location.requestCalls, afterFirstLoad);
  });

  testWidgets('nearby food is requested once per load, not twice', (
    tester,
  ) async {
    listings.results = [listing()];

    await pumpHome(tester);
    await settle(tester);

    expect(listings.nearbyCalls, 1);
  });

  testWidgets('a stored fix is reused instead of asking the platform', (
    tester,
  ) async {
    listings.results = [listing()];

    await pumpHome(
      tester,
      storedFix: DeviceLocation(
        latitude: 1.0,
        longitude: 2.0,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    await settle(tester);

    // The gate already stored a fix, so Home has no reason to re-ask — this
    // is what keeps a GPS wait off the path to Home.
    expect(location.requestCalls, 0);
    expect(listings.nearbyCalls, 1);
  });

  testWidgets('the impact count shows nothing until it is known', (
    tester,
  ) async {
    listings.results = const [];
    await pumpHome(tester);
    await settle(tester);

    // Zero completed rescues is the real answer here, and renders as 0.
    expect(find.text('meals rescued'), findsOneWidget);
    expect(find.text('—'), findsWidgets); // weight is genuinely unknown
  });
}
