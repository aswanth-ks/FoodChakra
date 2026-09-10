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
import 'package:foodloop/features/auth/presentation/email_verification_screen.dart';
import 'package:foodloop/features/auth/presentation/reset_password_screen.dart';
import 'package:foodloop/features/auth/presentation/sign_in_screen.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:go_router/go_router.dart';

Account verifiedAccount() => const Account(
  id: 'u1',
  email: 'asha@example.com',
  fullName: 'Asha Rao',
  role: AccountRole.consumer,
  status: AccountStatus.active,
  emailVerified: true,
);

/// Records what the screens asked the backend to do.
///
/// Every method here can be made to fail, because the interesting cases in
/// this stage are the failures: a wrong code, an expired one, a mail server
/// that is down. A screen that shows success after any of those would be the
/// exact defect the stage exists to prevent.
class RecordingAuthRepository implements AuthRepository {
  Account? session;

  final List<String> registered = [];
  final List<({String email, String code})> verified = [];
  final List<String> resent = [];
  final List<String> forgot = [];
  final List<({String email, String code, String password})> reset = [];

  Failure? registerFailure;
  Failure? verifyFailure;
  Failure? resendFailure;
  Failure? forgotFailure;
  Failure? resetFailure;
  Failure? signInFailure;

  @override
  Future<Account?> restoreSession() async => session;

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    if (signInFailure != null) throw signInFailure!;
    return session = verifiedAccount();
  }

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (registerFailure != null) throw registerFailure!;
    registered.add(email);
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    if (verifyFailure != null) throw verifyFailure!;
    verified.add((email: email, code: code));
  }

  @override
  Future<void> resendVerification(String email) async {
    if (resendFailure != null) throw resendFailure!;
    resent.add(email);
  }

  @override
  Future<void> forgotPassword(String email) async {
    if (forgotFailure != null) throw forgotFailure!;
    forgot.add(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (resetFailure != null) throw resetFailure!;
    reset.add((email: email, code: code, password: newPassword));
  }

  @override
  Future<void> signOut() async => session = null;
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
  Future<FoodListing> byId(String id) async => throw const NotFoundFailure();

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async =>
      const [];

  @override
  Future<FoodListing> create(NewListing listing) async =>
      throw const NotFoundFailure();

  @override
  Future<FoodListing> cancel(String id, {String? reason}) async =>
      throw const NotFoundFailure();
}

class EmptyRescues implements RescueRepository {
  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Harness {
  Harness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

void main() {
  late RecordingAuthRepository auth;

  setUpAll(() async {
    final bytes = File('assets/fonts/PlusJakartaSans[wght].ttf')
        .readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  setUp(() => auth = RecordingAuthRepository());

  Future<Harness> pumpApp(WidgetTester tester, {String? at}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        listingRepositoryProvider.overrideWithValue(EmptyListings()),
        rescueRepositoryProvider.overrideWithValue(EmptyRescues()),
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
    // Past the splash animation and the session restore.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    if (at != null) {
      router.go(at);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    return Harness(container, router);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The sign-in screen has no widget keys; its two fields are the only
  /// text fields on it, which is how `sign_in_screen_test.dart` drives it too.
  Future<void> signInAs(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.enterText(find.byType(TextFormField).last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    final boxes = find.byType(TextField);
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(boxes.at(i), code[i]);
      await tester.pump();
    }
  }

  // ------------------------------------------------------- create account

  group('registration', () {
    Future<Harness> submitRegistration(WidgetTester tester) async {
      final harness = await pumpApp(tester, at: '/create-account');

      await tester.enterText(
        find.byKey(const Key('createAccount_name')),
        'Asha Rao',
      );
      await tester.enterText(
        find.byKey(const Key('createAccount_email')),
        'asha@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('createAccount_password')),
        'a-good-password',
      );
      await tester.tap(find.text('Create account'));
      await settle(tester);
      return harness;
    }

    testWidgets('a successful sign-up opens the verification screen', (
      tester,
    ) async {
      final harness = await submitRegistration(tester);

      expect(auth.registered, ['asha@example.com']);
      expect(harness.location, contains('/verify-email'));
      expect(harness.location, contains('asha%40example.com'));
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });

    testWidgets('registering does not sign the user in', (tester) async {
      final harness = await submitRegistration(tester);

      // The whole point of verification: an account exists, but nothing has
      // let its owner into the app yet.
      expect(harness.container.read(authControllerProvider).value, isNull);
      expect(harness.location, isNot(contains('/home')));
    });

    testWidgets('a mail failure keeps the user on the form', (tester) async {
      // 503 from the backend: the account was created, but no code was sent.
      // Sending the user to wait for an email that never arrives would be a
      // lie the screen has no way to correct.
      auth.registerFailure = const ServiceUnavailableFailure(
        'Email delivery is not configured on this server. No code was sent.',
      );

      final harness = await submitRegistration(tester);

      expect(harness.location, '/create-account');
      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(find.textContaining('No code was sent'), findsOneWidget);
    });
  });

  // -------------------------------------------------------- verification

  group('email verification', () {
    testWidgets('a code is sent to the backend and opens sign-in', (
      tester,
    ) async {
      final harness = await pumpApp(
        tester,
        at: '/verify-email?email=asha%40example.com',
      );

      await enterCode(tester, '481920');
      await settle(tester);

      expect(auth.verified.single.code, '481920');
      expect(auth.verified.single.email, 'asha@example.com');
      // Verification proves the address, not the password — so the user
      // signs in rather than landing in the app.
      expect(harness.location, '/login');
    });

    testWidgets('a rejected code leaves the user on the screen', (
      tester,
    ) async {
      auth.verifyFailure = const ValidationFailure(
        'That code is not valid or has expired. Request a new one.',
      );

      final harness = await pumpApp(
        tester,
        at: '/verify-email?email=asha%40example.com',
      );

      await enterCode(tester, '000000');
      await settle(tester);

      expect(harness.location, contains('/verify-email'));
      expect(find.textContaining('not valid or has expired'), findsOneWidget);
    });

    testWidgets('an exhausted code shows the server wording', (tester) async {
      auth.verifyFailure = const TooManyAttemptsFailure(
        'Too many attempts. Please try again later.',
      );

      await pumpApp(tester, at: '/verify-email?email=asha%40example.com');
      await enterCode(tester, '111111');
      await settle(tester);

      expect(find.textContaining('Too many attempts'), findsOneWidget);
    });

    testWidgets('resend asks the backend for a new code', (tester) async {
      await pumpApp(tester, at: '/verify-email?email=asha%40example.com');

      // The control unlocks after its countdown.
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text('Resend code'));
      await settle(tester);

      expect(auth.resent, ['asha@example.com']);
    });

    testWidgets('a cooled-down resend reports the refusal', (tester) async {
      auth.resendFailure = const TooManyAttemptsFailure(
        'A code was sent recently. Wait a moment before asking again.',
      );

      await pumpApp(tester, at: '/verify-email?email=asha%40example.com');
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text('Resend code'));
      await settle(tester);

      expect(find.textContaining('sent recently'), findsOneWidget);
    });

    testWidgets('the screen never shows a code of its own', (tester) async {
      await pumpApp(tester, at: '/verify-email?email=asha%40example.com');

      // Nothing in the app knows a code. If one were ever rendered here it
      // could only have come from an API response that should not carry it.
      expect(find.textContaining(RegExp(r'\d{6}')), findsNothing);
    });
  });

  // --------------------------------------------------------------- login

  group('login', () {
    testWidgets('a verified account reaches the app', (tester) async {
      final harness = await pumpApp(tester, at: '/login');

      await signInAs(tester, 'asha@example.com', 'a-good-password');
      await settle(tester);

      expect(harness.location, '/home');
    });

    testWidgets('an unverified account is sent to the code screen', (
      tester,
    ) async {
      auth.signInFailure = const EmailNotVerifiedFailure(
        'Verify your email address to sign in.',
      );

      final harness = await pumpApp(tester, at: '/login');

      await signInAs(tester, 'new@example.com', 'a-good-password');
      await settle(tester);

      expect(harness.location, contains('/verify-email'));
      expect(harness.location, contains('new%40example.com'));
      // No session was created, so the gate has nothing to let through.
      expect(harness.container.read(authControllerProvider).value, isNull);
    });

    testWidgets('a wrong password does not go to verification', (
      tester,
    ) async {
      auth.signInFailure = const UnauthorizedFailure(
        'Invalid email or password.',
      );

      final harness = await pumpApp(tester, at: '/login');

      await signInAs(tester, 'asha@example.com', 'wrong-password');
      await settle(tester);

      expect(harness.location, '/login');
      expect(find.textContaining('Invalid email or password'), findsOneWidget);
    });

    testWidgets('a network failure is reported, not swallowed', (
      tester,
    ) async {
      auth.signInFailure = const NetworkFailure();

      final harness = await pumpApp(tester, at: '/login');

      await signInAs(tester, 'asha@example.com', 'a-good-password');
      await settle(tester);

      expect(harness.location, '/login');
      expect(find.textContaining('No internet connection'), findsOneWidget);
    });
  });

  // ----------------------------------------------------- password reset

  group('forgot password', () {
    Future<Harness> requestReset(WidgetTester tester) async {
      final harness = await pumpApp(tester, at: '/forgot-password');
      await tester.enterText(
        find.byKey(const Key('forgotPassword_email')),
        'asha@example.com',
      );
      await tester.tap(find.text('Send reset code'));
      await settle(tester);
      return harness;
    }

    testWidgets('requesting a code opens the reset screen', (tester) async {
      await requestReset(tester);

      expect(auth.forgot, ['asha@example.com']);
      // Asserted on the rendered screen rather than the URL: this step is a
      // push, and `currentConfiguration.uri` keeps reporting the route the
      // stack was pushed from.
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    testWidgets('an unknown address looks exactly the same', (tester) async {
      // The backend answers identically either way, so the app must not
      // branch on the result — that would rebuild the leak on the client.
      await pumpApp(tester, at: '/forgot-password');
      await tester.enterText(
        find.byKey(const Key('forgotPassword_email')),
        'nobody@example.com',
      );
      await tester.tap(find.text('Send reset code'));
      await settle(tester);

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.textContaining('no account'), findsNothing);
      expect(find.textContaining('not found'), findsNothing);
    });
  });

  group('reset password', () {
    Future<Harness> openReset(WidgetTester tester) =>
        pumpApp(tester, at: '/reset-password?email=asha%40example.com');

    Future<void> submit(
      WidgetTester tester, {
      String code = '481920',
      String password = 'a-brand-new-password',
    }) async {
      await tester.enterText(
        find.byKey(const Key('resetPassword_code')),
        code,
      );
      await tester.enterText(
        find.byKey(const Key('resetPassword_password')),
        password,
      );
      await tester.tap(find.text('Set new password'));
      await settle(tester);
    }

    testWidgets('a valid reset returns the user to sign-in', (tester) async {
      final harness = await openReset(tester);

      await submit(tester);

      expect(auth.reset.single.code, '481920');
      expect(auth.reset.single.password, 'a-brand-new-password');
      // No session is issued: the user signs in with what they just chose.
      expect(harness.location, '/login');
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('a rejected code shows the failure and stays put', (
      tester,
    ) async {
      auth.resetFailure = const ValidationFailure(
        'That code is not valid or has expired. Request a new one.',
      );

      final harness = await openReset(tester);
      await submit(tester, code: '000000');

      expect(harness.location, contains('/reset-password'));
      expect(find.textContaining('not valid or has expired'), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('a used code is refused like any other bad code', (
      tester,
    ) async {
      auth.resetFailure = const ValidationFailure(
        'That code is not valid or has expired. Request a new one.',
      );

      await openReset(tester);
      await submit(tester);

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    testWidgets('a short password never reaches the backend', (tester) async {
      await openReset(tester);
      await submit(tester, password: 'short');

      expect(auth.reset, isEmpty);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
    });

    testWidgets('a malformed code never reaches the backend', (tester) async {
      await openReset(tester);
      await submit(tester, code: '12');

      expect(auth.reset, isEmpty);
      expect(find.text('The code is 6 digits.'), findsOneWidget);
    });

    testWidgets('resend goes back through forgot-password', (tester) async {
      await openReset(tester);

      await tester.tap(find.text('Send another code'));
      await settle(tester);

      expect(auth.forgot, ['asha@example.com']);
    });

    testWidgets('a successful reset clears any existing session', (
      tester,
    ) async {
      // The backend revokes every refresh session, so a local one would only
      // point at tokens the server has already thrown away.
      auth.session = verifiedAccount();
      final harness = await openReset(tester);

      await submit(tester);

      expect(harness.container.read(authControllerProvider).value, isNull);
      expect(harness.location, '/login');
    });
  });
}
