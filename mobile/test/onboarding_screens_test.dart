import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/onboarding/presentation/share_surplus_screen.dart';
import 'package:foodloop/features/onboarding/presentation/welcome_screen.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  group('WelcomeScreen', () {
    testWidgets('renders the Stitch copy and controls', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Good food deserves another destination.'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Get Started fires its callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(WelcomeScreen(onGetStarted: () => tapped = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      expect(tapped, isTrue);
    });
  });

  group('ShareSurplusScreen', () {
    testWidgets('renders headline, steps and CTA', (tester) async {
      await tester.pumpWidget(_wrap(const ShareSurplusScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Turn extra food\ninto something useful.'), findsOneWidget);
      for (final s in ['SHARE', 'CONNECT', 'RESCUE']) {
        expect(find.text(s), findsOneWidget);
      }
      expect(find.text('40 servings ready to share'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    final sizes = [
      const Size(320, 568),
      const Size(390, 844),
      const Size(430, 932),
    ];
    final screens = <String, Widget>{
      'WelcomeScreen': const WelcomeScreen(),
      'ShareSurplusScreen': const ShareSurplusScreen(),
    };

    for (final size in sizes) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} has no overflow at ${size.width.toInt()}w', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_wrap(entry.value));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
