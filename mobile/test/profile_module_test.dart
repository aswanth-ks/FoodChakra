import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/router.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/features/auth/domain/account.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';
import 'package:foodloop/features/auth/domain/auth_repository.dart';
import 'package:foodloop/features/auth/presentation/auth_providers.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/change_password_screen.dart';
import 'package:foodloop/features/rescue/presentation/edit_profile_screen.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/personal_information_screen.dart';
import 'package:foodloop/features/rescue/presentation/profile_screen.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_location_cache.dart';
import 'support/inert_location_service.dart';

Account _account({String fullName = 'Asha Rao'}) => Account(
  id: 'u1',
  email: 'asha@example.com',
  fullName: fullName,
  role: AccountRole.consumer,
  status: AccountStatus.active,
  emailVerified: true,
  createdAt: DateTime.utc(2026, 3, 14),
);

/// The whole profile contract: what is stored, what a save does to it.
class _FakeAuth implements AuthRepository {
  _FakeAuth();

  Account? current = _account();
  Failure? updateFailure;
  Failure? changePasswordFailure;

  final savedNames = <String>[];
  int changePasswordCalls = 0;
  int signOutCalls = 0;
  ({String current, String next})? lastPasswordChange;

  /// Holds a save open so a test can look at the in-flight state.
  Completer<void>? gate;

  @override
  Future<Account?> restoreSession() async => current;

  @override
  Future<Account> updateProfile({required String fullName}) async {
    if (gate != null) await gate!.future;
    if (updateFailure != null) throw updateFailure!;
    savedNames.add(fullName);
    // The server is the authority on what was stored; the app shows this.
    current = _account(fullName: fullName);
    return current!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    lastPasswordChange = (current: currentPassword, next: newPassword);
    if (changePasswordFailure != null) throw changePasswordFailure!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _EmptyListings implements ListingRepository {
  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async =>
      const [];

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

void main() {
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/PlusJakartaSans[wght].ttf',
    ).readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  late _FakeAuth auth;

  setUp(() => auth = _FakeAuth());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pumps the real router so every assertion is about the real gate and the
  /// real routes, not a re-implementation of them.
  Future<GoRouter> pumpApp(WidgetTester tester, {String? at}) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        locationServiceProvider.overrideWithValue(const InertLocationService()),
        authRepositoryProvider.overrideWithValue(auth),
        listingRepositoryProvider.overrideWithValue(_EmptyListings()),
        rescueRepositoryProvider.overrideWithValue(_EmptyRescues()),
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
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2000));
    await settle(tester);
    router.go(at ?? AppRoutes.profile);
    await settle(tester);
    return router;
  }

  String where(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('Profile shows the real account', () {
    testWidgets('name, email and role come from the session', (tester) async {
      await pumpApp(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Asha Rao'), findsWidgets);
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(find.text('Consumer'), findsOneWidget);
    });

    testWidgets('no invented identity survives anywhere', (tester) async {
      auth.current = _account(fullName: 'Real Person');
      await pumpApp(tester);

      // The names and figures the screen used to ship with as defaults.
      // "FoodLoop member since 2026" is deliberately absent from this list:
      // it is now derived from the account's real `createdAt`, so it is a
      // true statement rather than a leftover.
      for (final invented in ['Aswanth', 'John', 'Demo', '48']) {
        expect(find.text(invented), findsNothing, reason: invented);
      }
      expect(find.text('Real Person'), findsWidgets);
    });

    testWidgets('rows with nowhere to go say so instead of doing nothing', (
      tester,
    ) async {
      await pumpApp(tester);

      // A row that looks live and does nothing is worse than one that admits
      // it is not built: the user cannot tell whether the app is broken.
      expect(find.text('Soon'), findsWidgets);
      expect(find.text('Saved locations'), findsOneWidget);
    });
  });

  group('Edit profile', () {
    testWidgets('opens from Profile', (tester) async {
      await pumpApp(tester);

      await tester.ensureVisible(find.text('Edit profile').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Edit profile'));
      await settle(tester);

      // Asserted on the screen rather than the URI: these are pushed routes,
      // and what matters is that the user is looking at the right page.
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    testWidgets('starts from the stored name, with email read-only', (
      tester,
    ) async {
      await pumpApp(tester, at: AppRoutes.editProfile);

      expect(find.widgetWithText(TextFormField, 'Asha Rao'), findsOneWidget);
      // The address is shown but cannot be typed into: changing it would move
      // where verification codes go.
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(
        find.textContaining('cannot be changed here'),
        findsOneWidget,
      );
    });

    testWidgets('an empty name is refused and never reaches the server', (
      tester,
    ) async {
      await pumpApp(tester, at: AppRoutes.editProfile);

      await tester.enterText(find.byType(TextFormField).first, '   ');
      await settle(tester);
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      expect(find.text('Your name cannot be empty.'), findsOneWidget);
      expect(auth.savedNames, isEmpty);
    });

    testWidgets('an over-long name is refused', (tester) async {
      await pumpApp(tester, at: AppRoutes.editProfile);

      await tester.enterText(find.byType(TextFormField).first, 'a' * 121);
      await settle(tester);

      expect(auth.savedNames, isEmpty);
    });

    testWidgets('saving sends the trimmed name and returns to Profile', (
      tester,
    ) async {
      // Pushed from Profile, as a user reaches it — a directly-opened route
      // has nothing beneath it to return to.
      await pumpApp(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Edit profile'));
      await settle(tester);

      await tester.enterText(find.byType(TextFormField).first, '  Asha K  ');
      await settle(tester);
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      expect(auth.savedNames, ['Asha K']);
      // Back on Profile, already showing the stored value.
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Asha K'), findsWidgets);
    });

    testWidgets('the saved name is what a later load shows', (tester) async {
      await pumpApp(tester, at: AppRoutes.editProfile);
      await tester.enterText(find.byType(TextFormField).first, 'Asha K');
      await settle(tester);
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      // What the repository now holds is what a fresh restore returns, so a
      // relaunch shows the persisted value rather than the old one.
      expect((await auth.restoreSession())!.fullName, 'Asha K');
    });

    testWidgets('an unchanged name cannot be saved', (tester) async {
      await pumpApp(tester, at: AppRoutes.editProfile);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      // Nothing to save means no round trip to achieve nothing.
      expect(button.onPressed, isNull);
    });

    testWidgets('a failed save stays put and says why', (tester) async {
      auth.updateFailure = const NetworkFailure();
      await pumpApp(tester, at: AppRoutes.editProfile);

      await tester.enterText(find.byType(TextFormField).first, 'Asha K');
      await settle(tester);
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      expect(find.byType(EditProfileScreen), findsOneWidget);
      // The server's own wording, not a claim that it worked.
      expect(
        find.text('No internet connection.'),
        findsOneWidget,
      );
    });

    testWidgets('a second tap while saving does not send twice', (
      tester,
    ) async {
      auth.gate = Completer<void>();
      await pumpApp(tester, at: AppRoutes.editProfile);

      await tester.enterText(find.byType(TextFormField).first, 'Asha K');
      await settle(tester);
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The button is a spinner for the duration, so there is nothing to tap.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Save changes'), findsNothing);

      auth.gate!.complete();
      await settle(tester);
      expect(auth.savedNames.length, 1);
    });
  });

  group('Personal information', () {
    testWidgets('opens from Profile and shows the real fields', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.ensureVisible(find.text('Personal information').first);
      await tester.pump();
      await tester.tap(find.text('Personal information').first);
      await settle(tester);

      expect(find.byType(PersonalInformationScreen), findsOneWidget);
      expect(find.text('Asha Rao'), findsWidgets);
      expect(find.text('asha@example.com'), findsWidgets);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Consumer'), findsOneWidget);
      expect(find.text('14 March 2026'), findsOneWidget);
    });

    testWidgets('a missing join date is admitted, not invented', (
      tester,
    ) async {
      auth.current = Account(
        id: 'u1',
        email: 'asha@example.com',
        fullName: 'Asha Rao',
        role: AccountRole.consumer,
        status: AccountStatus.active,
        emailVerified: false,
      );

      await pumpApp(tester, at: AppRoutes.personalInformation);

      expect(find.text('Not provided'), findsOneWidget);
      expect(find.text('Not verified'), findsOneWidget);
    });
  });

  group('Change password', () {
    testWidgets('opens from Profile', (tester) async {
      await pumpApp(tester);

      await tester.ensureVisible(find.text('Change password').first);
      await tester.pump();
      await tester.tap(find.text('Change password').first);
      await settle(tester);

      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('mismatched confirmation is refused before any request', (
      tester,
    ) async {
      await pumpApp(tester, at: AppRoutes.changePassword);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'correct-horse');
      await tester.enterText(fields.at(1), 'battery-staple-9');
      await tester.enterText(fields.at(2), 'something-else');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await settle(tester);

      expect(find.text('Both entries must match.'), findsOneWidget);
      expect(auth.changePasswordCalls, 0);
    });

    testWidgets('a short new password is refused before any request', (
      tester,
    ) async {
      await pumpApp(tester, at: AppRoutes.changePassword);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'correct-horse');
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'short');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await settle(tester);

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(auth.changePasswordCalls, 0);
    });

    testWidgets('a successful change signs the user out', (tester) async {
      await pumpApp(tester, at: AppRoutes.changePassword);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'correct-horse');
      await tester.enterText(fields.at(1), 'battery-staple-9');
      await tester.enterText(fields.at(2), 'battery-staple-9');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await settle(tester);

      expect(auth.changePasswordCalls, 1);
      expect(auth.lastPasswordChange?.current, 'correct-horse');
      expect(auth.lastPasswordChange?.next, 'battery-staple-9');
      // The server revoked every session, so believing in one locally would
      // leave the app filling with 401s.
      expect(auth.signOutCalls, 1);
      // The gate moves the user out of every account screen.
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    testWidgets('a wrong current password says so and keeps the session', (
      tester,
    ) async {
      auth.changePasswordFailure = const UnauthorizedFailure(
        'Your current password is incorrect.',
      );
      await pumpApp(tester, at: AppRoutes.changePassword);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'not-my-password');
      await tester.enterText(fields.at(1), 'battery-staple-9');
      await tester.enterText(fields.at(2), 'battery-staple-9');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await settle(tester);

      expect(find.text('Your current password is incorrect.'), findsOneWidget);
      expect(auth.signOutCalls, 0);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });
  });

  group('the profile routes are protected', () {
    for (final route in [
      AppRoutes.editProfile,
      AppRoutes.personalInformation,
      AppRoutes.changePassword,
    ]) {
      testWidgets('$route refuses a signed-out visitor', (tester) async {
        auth.current = null;

        final router = await pumpApp(tester, at: route);

        // No second auth check is written in these routes; the single gate in
        // session_gate.dart covers them because they are not public.
        expect(where(router), isNot(route));
        expect(where(router), anyOf(AppRoutes.login, AppRoutes.welcome));
      });
    }
  });
}
