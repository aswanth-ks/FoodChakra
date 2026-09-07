import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/auth/presentation/create_account_screen.dart';

Finder _fieldFor(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Widget _wrap([Widget? c]) =>
    MaterialApp(theme: AppTheme.light, home: c ?? const CreateAccountScreen());

void main() {
  testWidgets('renders the Stitch copy and controls', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Create your FoodLoop account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('or continue with'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates name, email and a short password', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Create a password.'), findsOneWidget);

    await tester.enterText(_fieldFor('createAccount_name'), 'Ada Lovelace');
    await tester.enterText(_fieldFor('createAccount_email'), 'ada@example.com');
    await tester.enterText(_fieldFor('createAccount_password'), 'short');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters.'), findsAtLeastNWidgets(1));
  });

  testWidgets('submits valid details', (tester) async {
    String? name, email, password;
    await tester.pumpWidget(
      _wrap(
        CreateAccountScreen(
          onCreateAccount: (n, e, p) {
            name = n;
            email = e;
            password = p;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_fieldFor('createAccount_name'), 'Ada Lovelace');
    await tester.enterText(_fieldFor('createAccount_email'), 'ada@example.com');
    await tester.enterText(_fieldFor('createAccount_password'), 'hunter22');
    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(name, 'Ada Lovelace');
    expect(email, 'ada@example.com');
    expect(password, 'hunter22');
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
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
