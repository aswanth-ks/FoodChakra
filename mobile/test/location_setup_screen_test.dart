import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/onboarding/presentation/location_setup_screen.dart';

Widget _wrap([Widget? c]) =>
    MaterialApp(theme: AppTheme.light, home: c ?? const LocationSetupScreen());

void main() {
  testWidgets('renders the Stitch copy and map markers', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Find food worth\nrescuing near you'), findsOneWidget);
    expect(find.text('Enable location'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    for (final d in ['400m', '650m', '800m']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(
      find.text('Your location is used only to power nearby rescue features.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary and secondary actions fire', (tester) async {
    var enabled = false;
    var notNow = false;
    await tester.pumpWidget(
      _wrap(LocationSetupScreen(
        onEnableLocation: () => enabled = true,
        onNotNow: () => notNow = true,
      )),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Enable location'));
    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(enabled, isTrue);
    expect(notNow, isTrue);
  });

  testWidgets('reduced motion does not run the radar loop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: LocationSetupScreen(),
        ),
      ),
    );
    // pumpAndSettle would time out if an infinite animation were running.
    await tester.pumpAndSettle();
    expect(find.text('Enable location'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(390, 844), const Size(430, 932)]) {
    testWidgets('no overflow at ${size.width.toInt()}w', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
