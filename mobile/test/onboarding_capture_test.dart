import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/features/onboarding/presentation/share_surplus_screen.dart';
import 'package:foodloop/features/onboarding/presentation/welcome_screen.dart';

void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/PlusJakartaSans[wght].ttf').readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  for (final e in {'welcome': const WelcomeScreen(), 'share': const ShareSurplusScreen()}.entries) {
    testWidgets('capture ${e.key}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: e.value));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/onboarding_${e.key}.png'),
      );
    });
  }
}
