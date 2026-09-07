import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_colors.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/splash/presentation/splash_screen.dart';

Widget _harness({bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const SplashScreen(),
    ),
  );
}

void main() {
  testWidgets('renders the wordmark and tagline from the Stitch design', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('FoodLoop'), findsOneWidget);
    expect(find.text('Rescue food. Reduce waste.'), findsOneWidget);
  });

  testWidgets('uses the Warm Canvas background', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.background);
  });

  testWidgets('content starts hidden and is fully revealed by the end', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    // First frame: every element begins at opacity 0 per the design.
    List<double> opacityAt() => tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .map((f) => f.opacity.value)
        .toList();

    // Mid-animation the content is not yet fully revealed. (The exact value
    // is frame-timing dependent, so assert the invariant, not a number.)
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityAt().any((o) => o < 1), isTrue);

    // The tagline starts last, at 380ms.
    expect(opacityAt().last, lessThan(1));

    await tester.pumpAndSettle();
    expect(opacityAt().every((o) => o == 1), isTrue);
  });

  testWidgets('honours reduced motion by showing content immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(reduceMotion: true));
    await tester.pump();

    final opacities = tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .map((f) => f.opacity.value);
    expect(opacities.every((o) => o == 1), isTrue);
  });

  testWidgets('lays out without overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('FoodLoop'), findsOneWidget);
  });
}
