import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/router.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/features/auth/domain/account.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';
import 'package:foodloop/features/auth/domain/auth_repository.dart';
import 'package:foodloop/features/auth/presentation/auth_providers.dart';
import 'package:foodloop/features/auth/presentation/sign_in_screen.dart';
import 'package:foodloop/features/home/presentation/home_screen.dart';
import 'package:foodloop/features/onboarding/presentation/welcome_screen.dart';
import 'package:foodloop/features/partner/presentation/partner_home_screen.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:foodloop/features/splash/presentation/splash_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';

import 'support/fake_location_cache.dart';
import 'support/inert_location_service.dart';

Account account({AccountRole role = AccountRole.consumer}) => Account(
  id: 'u1',
  email: 'asha@example.com',
  fullName: 'Asha Rao',
  role: role,
  status: AccountStatus.active,
  emailVerified: true,
);

/// Stands in for the network. `restoreSession` is the whole startup contract:
/// an account, null (no session, or one the server refused and the repository
/// cleared), or a `Failure`.
class FakeAuthRepository implements AuthRepository {
  Account? restored;
  Failure? restoreFailure;
  int restoreCalls = 0;
  int signOutCalls = 0;
  int registerCalls = 0;

  @override
  Future<Account?> restoreSession() async {
    restoreCalls++;
    if (restoreFailure != null) throw restoreFailure!;
    return restored;
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async => restored = account();

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    // Deliberately does not set `restored`: registering creates no session.
    registerCalls++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    restored = null;
  }

  // Stage J's unauthenticated endpoints. None of them produces a session, so
  // none of them affects what the router's gate decides.
  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {}

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}
}

class _SlowAuthRepository extends FakeAuthRepository {
  _SlowAuthRepository(this._pending);

  final Future<Account?> _pending;

  @override
  Future<Account?> restoreSession() {
    restoreCalls++;
    return _pending;
  }
}

/// The protected screens have to render something. None of this is under
/// test; it only stops a network error masking what the guard did.
class EmptyListingRepository implements ListingRepository {
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
  Future<FoodListing> byId(String id) async =>
      throw const NotFoundFailure('gone');

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async =>
      const [];

  @override
  Future<FoodListing> create(NewListing listing) async =>
      throw const NotFoundFailure('gone');

  @override
  Future<FoodListing> cancel(String id, {String? reason}) async =>
      throw const NotFoundFailure('gone');
}

class EmptyRescueRepository implements RescueRepository {
  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bundles what a test needs to drive and inspect the router.
class RouterHandle {
  RouterHandle(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

void main() {
  // The real bundled font, for the same reason the golden capture loads it:
  // the test fallback font has different metrics, and every screen here was
  // laid out against this one.
  setUpAll(() async {
    final bytes = File('assets/fonts/PlusJakartaSans[wght].ttf')
        .readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  /// Pumps the real app router, so every assertion is about the actual gate
  /// rather than a re-implementation of its logic.
  Future<RouterHandle> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        // No platform channel for these tests to hang on either.
        locationServiceProvider.overrideWithValue(
          const InertLocationService(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        listingRepositoryProvider.overrideWithValue(EmptyListingRepository()),
        rescueRepositoryProvider.overrideWithValue(EmptyRescueRepository()),
        currentOriginProvider.overrideWith(
          (ref) async => (latitude: 10.9, longitude: 78.0),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    return RouterHandle(container, router);
  }

  /// Advances a fixed number of frames.
  ///
  /// Not `pumpAndSettle`: several screens carry a looping animation, so there
  /// is no frame at which the tree goes quiet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Runs past the splash animation and its hold, then lets the redirect and
  /// the resulting screen settle.
  Future<void> finishSplash(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    await tester.pump();
  }

  group('startup', () {
    testWidgets('no session lands on the onboarding flow', (tester) async {
      await pumpApp(tester);
      expect(find.byType(SplashScreen), findsOneWidget);

      await finishSplash(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(auth.restoreCalls, 1);
    });

    testWidgets('a valid session goes straight to Home', (tester) async {
      auth.restored = account();
      final handle = await pumpApp(tester);

      await finishSplash(tester);

      expect(handle.location, '/home');
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('a partner session goes to the partner home', (tester) async {
      auth.restored = account(role: AccountRole.partner);
      final handle = await pumpApp(tester);

      await finishSplash(tester);

      // The role came from the restored session, which is the server's
      // answer. Nothing here looked at the email address.
      expect(handle.location, '/partner');
      expect(find.byType(PartnerHomeScreen), findsOneWidget);
    });

    testWidgets('a refused session cannot reach Home', (tester) async {
      // What a suspended or expired session looks like once the repository
      // has cleared it: a 401 or 403 becomes null, exactly like signed out.
      auth.restored = null;
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      handle.router.go('/home');
      await settle(tester);

      expect(handle.location, '/login');
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('a network failure does not fake a session', (tester) async {
      auth.restoreFailure = const NetworkFailure();
      final handle = await pumpApp(tester);

      await finishSplash(tester);

      expect(find.byType(HomeScreen), findsNothing);
      expect(handle.location, '/onboarding/welcome');
    });

    testWidgets('the splash holds until the restore settles', (tester) async {
      final pending = Completer<Account?>();
      auth = _SlowAuthRepository(pending.future);
      final handle = await pumpApp(tester);

      // The animation has finished, but the session has not arrived yet.
      await finishSplash(tester);
      expect(find.byType(SplashScreen), findsOneWidget);

      pending.complete(account());
      await settle(tester);

      expect(handle.location, '/home');
    });
  });

  group('route guard', () {
    const guarded = [
      '/home',
      '/explore',
      '/give',
      '/activity',
      '/impact',
      '/profile',
      '/rescue/r1',
      '/handover/l1',
      '/partner',
      '/partner/surplus',
    ];

    for (final route in guarded) {
      testWidgets('unauthenticated cannot reach $route', (tester) async {
        final handle = await pumpApp(tester);
        await finishSplash(tester);

        handle.router.go(route);
        await settle(tester);

        expect(handle.location, '/login', reason: '$route must be guarded');
      });
    }

    testWidgets('an authenticated user reaches protected routes', (
      tester,
    ) async {
      auth.restored = account();
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      for (final route in const ['/explore', '/give', '/activity', '/impact']) {
        handle.router.go(route);
        await settle(tester);
        expect(handle.location, route);
      }
    });

    testWidgets('an authenticated user is not sent back through onboarding', (
      tester,
    ) async {
      auth.restored = account();
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      handle.router.go('/login');
      await settle(tester);
      expect(handle.location, '/home');

      handle.router.go('/onboarding/welcome');
      await settle(tester);
      expect(handle.location, '/home');
    });

    testWidgets('sign-in stays reachable while signed out', (tester) async {
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      handle.router.go('/login');
      await settle(tester);

      expect(handle.location, '/login');
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('an unchecked session', () {
    testWidgets('a network failure does not show onboarding', (tester) async {
      // Credentials are on the device; the server just could not be asked.
      auth.restoreFailure = const SessionUnverifiedFailure(NetworkFailure());

      final handle = await pumpApp(tester);
      await finishSplash(tester);

      // Telling a signed-in user they have no account is both false and
      // unrecoverable without signing in again.
      expect(handle.location, isNot(AppRoutes.welcome));
      expect(handle.location, AppRoutes.splash);
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.text(
          'You are still signed in — check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('it still lets nobody into a protected route', (tester) async {
      auth.restoreFailure = const SessionUnverifiedFailure(NetworkFailure());

      final handle = await pumpApp(tester);
      await finishSplash(tester);
      handle.router.go(AppRoutes.home);
      await settle(tester);

      // A session nobody has validated stays unvalidated. Being offline is
      // not a way past `/auth/me`.
      expect(handle.location, AppRoutes.splash);
    });

    testWidgets('Try again re-checks and recovers', (tester) async {
      auth.restoreFailure = const SessionUnverifiedFailure(NetworkFailure());

      final handle = await pumpApp(tester);
      await finishSplash(tester);
      expect(handle.location, AppRoutes.splash);
      final callsBefore = auth.restoreCalls;

      // The network comes back.
      auth.restoreFailure = null;
      auth.restored = account();

      await tester.tap(find.text('Try again'));
      await finishSplash(tester);
      await settle(tester);

      expect(auth.restoreCalls, greaterThan(callsBefore));
      expect(handle.location, AppRoutes.home);
    });

    testWidgets('an empty restore still means onboarding', (tester) async {
      // No failure, no account: genuinely signed out, which is a different
      // thing and must keep its existing behaviour.
      auth
        ..restoreFailure = null
        ..restored = null;

      final handle = await pumpApp(tester);
      await finishSplash(tester);

      expect(handle.location, AppRoutes.welcome);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('logout', () {
    testWidgets('signing out clears the session and leaves the app', (
      tester,
    ) async {
      auth.restored = account();
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      await handle.container.read(authControllerProvider.notifier).signOut();
      await settle(tester);

      expect(auth.signOutCalls, 1);
      expect(handle.location, '/login');
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('protected routes stay closed after signing out', (
      tester,
    ) async {
      auth.restored = account();
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      await handle.container.read(authControllerProvider.notifier).signOut();
      await settle(tester);

      handle.router.go('/activity');
      await settle(tester);

      expect(handle.location, '/login');
    });
  });

  group('role', () {
    testWidgets('a partner-looking email grants nothing on its own', (
      tester,
    ) async {
      // The session says consumer; the address suggests otherwise. The router
      // must follow the session.
      auth.restored = Account(
        id: 'u2',
        email: 'manager@restaurant.foodloop.app',
        fullName: 'Ravi Kumar',
        role: AccountRole.consumer,
        status: AccountStatus.active,
        emailVerified: true,
      );
      final handle = await pumpApp(tester);
      await finishSplash(tester);

      expect(handle.location, '/home');
      expect(find.byType(PartnerHomeScreen), findsNothing);
    });
  });
}
