import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/onboarding/presentation/impact_screen.dart';

Widget _wrap() => MaterialApp(theme: AppTheme.light, home: const ImpactScreen());

void main() {
  testWidgets('renders the Stitch copy and metrics', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Every rescue counts.'), findsOneWidget);
    expect(find.text('FOOD RESCUED'), findsOneWidget);
    expect(find.text('Example impact'), findsOneWidget);
    expect(find.text('Small actions add up.'), findsOneWidget);
    for (final l in ['Meals', 'Food diverted', 'Rescue']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Start rescuing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start rescuing fires its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ImpactScreen(onStartRescuing: () => tapped = true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start rescuing'));
    expect(tapped, isTrue);
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
