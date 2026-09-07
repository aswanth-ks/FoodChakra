import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Shared onboarding chrome.
///
/// Both onboarding screens use the same skip control, page indicator, primary
/// call-to-action and sign-in prompt, so they are built once here.

/// Colours that appear only in the onboarding designs.
class OnboardingColors {
  const OnboardingColors._();

  /// Onboarding canvas — very slightly warmer than [AppColors.background].
  static const Color canvas = Color(0xFFFAF8F5);
  static const Color forest = Color(0xFF183B2B);
  static const Color forestDark = Color(0xFF132F22);
  static const Color forestPressed = Color(0xFF0F241A);
  static const Color accent = Color(0xFF2D6A4F);

  static const Color heading = Color(0xFF142018);
  static const Color body = Color(0xFF4F6355);
  static const Color muted = Color(0xFF56695D);
  static const Color skip = Color(0xFF5C7162);
  static const Color signInPrompt = Color(0xFF667A6D);

  static const Color dotInactive = Color(0xFFD5DCD7);
  static const Color dotInactiveAlt = Color(0xFFD1D9D3);
  static const Color hairline = Color(0xFFE5ECE7);
  static const Color tintSurface = Color(0xFFEDF4EF);
  static const Color chipSurface = Color(0xFFF4F3F0);
  static const Color chipBorder = Color(0xFFDCE6E0);
}

/// "Skip" control, right-aligned in the header.
class OnboardingSkipButton extends StatelessWidget {
  const OnboardingSkipButton({super.key, this.onPressed, this.compact = false});

  final VoidCallback? onPressed;

  /// Screen 3 uses a slightly smaller, bolder variant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: OnboardingColors.skip,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 8,
            vertical: 6,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 999 : 8),
          ),
        ),
        child: Text(
          'Skip',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: compact ? 12 : 14,
            fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
            fontVariations: [FontVariation('wght', compact ? 600 : 500)],
          ),
        ),
      ),
    );
  }
}

/// Carousel dots. The active dot is an elongated pill.
class OnboardingPageIndicator extends StatelessWidget {
  const OnboardingPageIndicator({
    super.key,
    required this.count,
    required this.activeIndex,
    this.dotSize = 5,
    this.activeWidth = 20,
    this.spacing = 6,
    this.inactiveColor = OnboardingColors.dotInactive,
  });

  final int count;
  final int activeIndex;
  final double dotSize;
  final double activeWidth;
  final double spacing;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${activeIndex + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == activeIndex;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? activeWidth : dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: isActive ? OnboardingColors.forest : inactiveColor,
                borderRadius: BorderRadius.circular(dotSize),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Full-width primary CTA with a trailing arrow.
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fontSize = 16,
    this.shadow,
  });

  final String label;
  final VoidCallback? onPressed;
  final double fontSize;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: OnboardingColors.forest,
            foregroundColor: Colors.white,
            disabledBackgroundColor: OnboardingColors.forest,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation('wght', 600)],
                  letterSpacing: -0.01 * fontSize,
                ),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Already have an account? Sign in"
class OnboardingSignInPrompt extends StatelessWidget {
  const OnboardingSignInPrompt({super.key, this.onSignIn, this.fontSize = 14});

  final VoidCallback? onSignIn;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontVariations: const [FontVariation('wght', 400)],
      color: OnboardingColors.signInPrompt,
    );

    return Text.rich(
      TextSpan(
        text: 'Already have an account? ',
        style: base,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onSignIn,
              child: Text(
                'Sign in',
                style: base.copyWith(
                  color: OnboardingColors.forest,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
