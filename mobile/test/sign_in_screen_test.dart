import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/auth/presentation/sign_in_screen.dart';

Widget _wrap([Widget? child]) =>
    MaterialApp(theme: AppTheme.light, home: child ?? const SignInScreen());

void main() {
  testWidgets('renders the Stitch copy and controls', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('or continue with'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Create one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an empty and a malformed email', (tester) async {
    String? seen;
    await tester.pumpWidget(
      _wrap(SignInScreen(onSignIn: (e, p) => seen = e)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(seen, isNull);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(seen, isNull);
  });

  testWidgets('submits valid credentials', (tester) async {
    String? email;
    String? password;
    await tester.pumpWidget(
      _wrap(SignInScreen(onSignIn: (e, p) {
        email = e;
        password = p;
      })),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.enterText(find.byType(TextFormField).last, 'hunter2');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(email, 'a@b.com');
    expect(password, 'hunter2');
  });

  testWidgets('password visibility toggles', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(390, 844), const Size(430, 932)]) {
    testWidgets('no overflow at ${size.width.toInt()}w', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
