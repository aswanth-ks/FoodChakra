import 'package:flutter/material.dart';

/// Colour tokens.
///
/// PLACEHOLDER VALUES — these are replaced with the exact palette extracted
/// from the approved Stitch designs in Phase 4. Never hardcode a `Color` in a
/// widget; always reference a token here so the swap is a one-file change.
class AppColors {
  const AppColors._();

  /// Rescue green — the brand's primary action colour.
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF60AD5E);

  /// Used for urgency and expiry warnings.
  static const Color accent = Color(0xFFF57C00);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF0277BD);

  static const Color background = Color(0xFFF7F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE0E4E0);

  static const Color textPrimary = Color(0xFF1A1C1A);
  static const Color textSecondary = Color(0xFF5C625C);
  static const Color textDisabled = Color(0xFF9AA09A);
  static const Color onPrimary = Color(0xFFFFFFFF);
}
