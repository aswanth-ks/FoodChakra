import 'package:flutter/material.dart';

/// Colour tokens — "Verdant Precision".
///
/// Values are taken verbatim from the Stitch design system
/// (project `FoodLoop Mobile Design System`, screen `Design System &
/// Components`). The names mirror the Material 3 roles used in the designs so a
/// Stitch class like `bg-surface-container` maps to an obvious token here.
///
/// Never hardcode a `Color` in a widget — add or reference a token instead.
class AppColors {
  const AppColors._();

  // ----- Brand -----
  /// Deepest brand green. Used for primary text-on-light and the logo's outer loop.
  static const Color primary = Color(0xFF002517);

  /// "Primary Forest" — the dominant brand fill.
  static const Color primaryContainer = Color(0xFF183B2B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF80A690);
  static const Color primaryFixed = Color(0xFFC4ECD4);
  static const Color primaryFixedDim = Color(0xFFA9CFB9);
  static const Color onPrimaryFixed = Color(0xFF002113);
  static const Color onPrimaryFixedVariant = Color(0xFF2B4E3D);

  /// Mid-tone green used for the logo's inner loop.
  static const Color surfaceTint = Color(0xFF436653);

  // ----- Secondary -----
  static const Color secondary = Color(0xFF2C694E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFAEEECB);
  static const Color onSecondaryContainer = Color(0xFF316E52);
  static const Color secondaryFixed = Color(0xFFB1F0CE);
  static const Color secondaryFixedDim = Color(0xFF95D4B3);

  // ----- Tertiary -----
  static const Color tertiary = Color(0xFF19221D);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF2E3732);
  static const Color onTertiaryContainer = Color(0xFF96A09A);

  // ----- Surfaces -----
  /// "Warm Canvas" — the app background. Warm off-white, not a cool grey.
  static const Color background = Color(0xFFFAF9F6);
  static const Color surface = Color(0xFFFAF9F6);
  static const Color surfaceBright = Color(0xFFFAF9F6);
  static const Color surfaceDim = Color(0xFFDBDAD7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F3F0);
  static const Color surfaceContainer = Color(0xFFEFEEEB);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E5);
  static const Color surfaceContainerHighest = Color(0xFFE3E2DF);
  static const Color surfaceVariant = Color(0xFFE3E2DF);

  // ----- Text -----
  /// "Text Ink" — primary body and heading colour.
  static const Color onSurface = Color(0xFF1A1C1A);
  static const Color onBackground = Color(0xFF1A1C1A);
  static const Color onSurfaceVariant = Color(0xFF414844);

  /// Wordmark ink. Slightly deeper than [onSurface].
  static const Color textInk = Color(0xFF142018);

  /// Muted supporting copy, e.g. the splash tagline.
  static const Color textMuted = Color(0xFF57685D);

  // ----- Outlines -----
  static const Color outline = Color(0xFF727973);
  static const Color outlineVariant = Color(0xFFC1C8C2);

  // ----- Status -----
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ----- Inverse -----
  static const Color inverseSurface = Color(0xFF2F312F);
  static const Color inverseOnSurface = Color(0xFFF2F1EE);
  static const Color inversePrimary = Color(0xFFA9CFB9);
}
