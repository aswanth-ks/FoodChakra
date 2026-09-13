import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/router.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/core/location/location_service.dart';
import 'package:foodloop/features/auth/domain/account.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';
import 'package:foodloop/features/auth/domain/auth_repository.dart';
import 'package:foodloop/features/auth/presentation/auth_providers.dart';
import 'package:foodloop/features/auth/presentation/sign_in_screen.dart';
import 'package:foodloop/features/onboarding/presentation/location_setup_screen.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:foodloop/core/location/location_cache.dart';

import 'support/fake_location_cache.dart';

Account account({AccountRole role = AccountRole.consumer}) => Account(
  id: 'u1',
  email: 'asha@example.com',
  fullName: 'Asha Rao',
  role: role,
  status: AccountStatus.active,
  emailVerified: true,
);

Position position({double latitude = 12.9, double longitude = 77.6}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Controls what the platform "would" answer, so the gate can be exercised
/// without a device. Production always goes to the real service.
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.readinessResult = LocationReadiness.needsSetup,
    LocationResult? result,
  }) : result = result ?? const LocationResult(LocationOutcome.denied);

  LocationReadiness readinessResult;
  LocationResult result;
  int requestCalls = 0;

  @override
  Future<LocationReadiness> readiness() async => readinessResult;

  @override
  Future<LocationResult> requestLocation() async {
    requestCalls++;
    return result;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class FakeAuthRepository implements AuthRepository {
  Account? restored;

  @override
  Future<Account?> restoreSession() async => restored;

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async => restored = account();

  @override
  Future<void> signOut() async => restored = null;

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

class EmptyListings implements ListingRepository {
  @override
  Future<List<FoodListing>> nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    List<String> foodTypes = const [],
    String? source,
    int limit = 20,
    int offset = 0,
  }) async => const [];

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

class Harness {
  Harness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
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

  late FakeAuthRepository auth;
  late FakeLocationService location;

  setUp(() {
    auth = FakeAuthRepository();
    location = FakeLocationService();
  });

  Future<Harness> pumpApp(WidgetTester tester, {String? at}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        authRepositoryProvider.overrideWithValue(auth),
        locationServiceProvider.overrideWithValue(location),
        listingRepositoryProvider.overrideWithValue(EmptyListings()),
        rescueRepositoryProvider.overrideWithValue(EmptyRescues()),
        currentOriginProvider.overrideWith(
          (ref) async => (latitude: 10.9, longitude: 78.0),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    if (at != null) router.go(at);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    return Harness(container, router);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      'asha@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'a-good-password');
    await tester.tap(find.text('Sign in'));
    await settle(tester);
  }

  group('route guard', () {
    testWidgets('a signed-out visitor cannot reach location onboarding', (
      tester,
    ) async {
      auth.restored = null;
      final harness = await pumpApp(tester);
      await settle(tester);

      harness.router.go('/onboarding/location');
      await settle(tester);

      // Protected, not public: the visitor is sent to sign in.
      expect(harness.location, '/login');
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('a signed-in user stays on location onboarding', (
      tester,
    ) async {
      auth.restored = account();
      final harness = await pumpApp(tester);
      await settle(tester);

      harness.router.go('/onboarding/location?next=/home');
      await settle(tester);

      // The bug this fixes: the redirect used to bounce an authenticated user
      // straight back to /home before the screen could ask for anything.
      expect(harness.location, contains('/onboarding/location'));
      expect(find.byType(LocationSetupScreen), findsOneWidget);
    });
  });

  group('post-login gate', () {
    testWidgets('without location, login lands on location onboarding', (
      tester,
    ) async {
      location.readinessResult = LocationReadiness.needsSetup;

      final harness = await pumpApp(tester, at: '/login');
      await settle(tester);
      await signIn(tester);

      expect(harness.location, contains('/onboarding/location'));
      expect(harness.location, contains('next=%2Fhome'));
      expect(find.byType(LocationSetupScreen), findsOneWidget);
    });

    testWidgets('with location already granted, login goes straight home', (
      tester,
    ) async {
      location
        ..readinessResult = LocationReadiness.ready
        ..result = LocationResult(
          LocationOutcome.granted,
          position: position(latitude: 51.5, longitude: -0.12),
        );

      final harness = await pumpApp(tester, at: '/login');
      await settle(tester);
      await signIn(tester);

      expect(harness.location, '/home');
      // The real fix was taken and stored on the way through.
      final stored = harness.container.read(deviceLocationProvider);
      expect(stored?.latitude, 51.5);
      expect(stored?.longitude, -0.12);
    });

    testWidgets('an inconclusive platform answer does not block the app', (
      tester,
    ) async {
      // No plugin channel: not evidence the user refused anything.
      location.readinessResult = LocationReadiness.unknown;

      final harness = await pumpApp(tester, at: '/login');
      await settle(tester);
      await signIn(tester);

      expect(harness.location, '/home');
    });
  });

  group('location onboarding outcomes', () {
    testWidgets('granting permission stores the fix and continues to home', (
      tester,
    ) async {
      auth.restored = account();
      location
        ..readinessResult = LocationReadiness.needsSetup
        ..result = LocationResult(
          LocationOutcome.granted,
          position: position(latitude: 9.1, longitude: 78.9),
        );

      final harness = await pumpApp(tester);
      await settle(tester);
      harness.router.go('/onboarding/location?next=/home');
      await settle(tester);

      expect(find.byType(LocationSetupScreen), findsOneWidget);
      expect(find.text('Enable location'), findsOneWidget);
      await tester.ensureVisible(find.text('Enable location'));
      await tester.pump();
      await tester.tap(find.text('Enable location'), warnIfMissed: true);
      await settle(tester);
      expect(location.requestCalls, greaterThan(0), reason: 'tap reached it');

      // The fix reaches application state as soon as it exists, before the
      // user has confirmed anything — it is a real reading either way.
      final stored = harness.container.read(deviceLocationProvider);
      expect(stored?.latitude, 9.1);
      expect(stored?.longitude, 78.9);

      // The screen now shows the map at that point first; Continue is what
      // leaves it.
      expect(harness.location, '/onboarding/location?next=/home');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await settle(tester);

      expect(harness.location, '/home');
    });

    testWidgets('a denial keeps the user on location onboarding', (
      tester,
    ) async {
      auth.restored = account();
      location
        ..readinessResult = LocationReadiness.needsSetup
        ..result = const LocationResult(LocationOutcome.denied);

      final harness = await pumpApp(tester);
      await settle(tester);
      harness.router.go('/onboarding/location?next=/home');
      await settle(tester);

      await tester.tap(find.text('Enable location'));
      await settle(tester);

      expect(harness.location, contains('/onboarding/location'));
      expect(
        find.text('FoodLoop needs your location to find surplus food near you.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      // Nothing was stored, and nothing invented.
      expect(harness.container.read(deviceLocationProvider), isNull);
    });
  });
}
