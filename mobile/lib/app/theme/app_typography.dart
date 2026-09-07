import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens — Plus Jakarta Sans.
///
/// Sizes, line heights, letter spacing and weights are taken verbatim from the
/// Stitch design system's Tailwind `fontSize` scale.
///
/// The bundled font is a *variable* font, so each style sets `fontVariations`
/// with an explicit `wght` axis alongside `fontWeight`. Setting only
/// `fontWeight` does not reliably select a weight from a variable font.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'PlusJakartaSans';

  static List<FontVariation> _wght(double weight) => [
    FontVariation('wght', weight),
  ];

  /// Converts Stitch's em-based letter spacing to Flutter's logical pixels.
  static double _tracking(double em, double fontSize) => em * fontSize;

  // ----- Display -----
  static final TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 48 / 40,
    letterSpacing: _tracking(-0.03, 40),
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
  );

  /// `display-lg-mobile` — the mobile display size.
  static final TextStyle displayLargeMobile = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: _tracking(-0.025, 32),
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
  );

  // ----- Headline -----
  static final TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 32 / 26,
    letterSpacing: _tracking(-0.02, 26),
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
  );

  static final TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 26 / 20,
    letterSpacing: _tracking(-0.015, 20),
    fontWeight: FontWeight.w600,
    fontVariations: _wght(600),
  );

  // ----- Title -----
  static final TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: _tracking(-0.01, 17),
    fontWeight: FontWeight.w600,
    fontVariations: _wght(600),
  );

  // ----- Body -----
  static final TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: _tracking(-0.005, 16),
    fontWeight: FontWeight.w400,
    fontVariations: _wght(400),
  );

  static final TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    fontVariations: _wght(400),
  );

  static final TextStyle bodyMediumStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0,
    fontWeight: FontWeight.w500,
    fontVariations: _wght(500),
  );

  // ----- Labels -----
  static final TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: _tracking(0.04, 12),
    fontWeight: FontWeight.w600,
    fontVariations: _wght(600),
  );

  static final TextStyle labelExtraSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: _tracking(0.06, 11),
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
  );

  // ----- Metrics -----
  static final TextStyle metricValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: _tracking(-0.02, 28),
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
  );

  // ----- Splash-specific -----
  // The splash wordmark and tagline use one-off sizes defined on the screen
  // itself rather than the shared scale, so they are declared here to keep the
  // literals out of the widget.

  /// "FoodLoop" wordmark: 28px / 600 / -0.025em / line-height 1.0.
  static final TextStyle splashWordmark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 1,
    letterSpacing: _tracking(-0.025, 28),
    fontWeight: FontWeight.w600,
    fontVariations: _wght(600),
    color: AppColors.textInk,
  );

  /// "Rescue food. Reduce waste." tagline: 13.5px / 400 / -0.01em.
  static final TextStyle splashTagline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    height: 1.625,
    letterSpacing: _tracking(-0.01, 13.5),
    fontWeight: FontWeight.w400,
    fontVariations: _wght(400),
    color: AppColors.textMuted,
  );

  /// The Material text theme, so `Theme.of(context).textTheme` is correct.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayLargeMobile,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    titleMedium: headlineMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    labelLarge: bodyMediumStrong,
    labelMedium: labelMedium,
    labelSmall: labelExtraSmall,
  ).apply(bodyColor: AppColors.onSurface, displayColor: AppColors.onSurface);
}
