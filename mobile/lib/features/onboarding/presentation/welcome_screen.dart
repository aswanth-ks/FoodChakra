import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/onboarding_widgets.dart';

/// Onboarding step 1 — "FoodLoop Welcome & Onboarding Screen".
///
/// Faithful translation of the Stitch design
/// (screen `862135f80727445281ad1faf328502d5`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    this.onGetStarted,
    this.onSkip,
    this.onSignIn,
  });

  final VoidCallback? onGetStarted;

  /// Skip and Sign in have no destination until auth exists (Phase 3).
  final VoidCallback? onSkip;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              // Header and footer stay put; only the middle scrolls, so the
              // CTA is always reachable and short screens never overflow.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OnboardingSkipButton(onPressed: onSkip),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          SizedBox(height: 8),
                          _HeroImage(),
                          SizedBox(height: 28),
                          _TextBlock(),
                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  const OnboardingPageIndicator(count: 3, activeIndex: 0),
                  const SizedBox(height: 24),
                  OnboardingPrimaryButton(
                    label: 'Get Started',
                    onPressed: onGetStarted,
                  ),
                  const SizedBox(height: 16),
                  OnboardingSignInPrompt(onSignIn: onSignIn),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // Stitch: `aspect-[4/3]`.
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: OnboardingColors.forest.withValues(alpha: 0.08),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12183B2B),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/onboarding_welcome.jpg',
            fit: BoxFit.cover,
            semanticLabel:
                'Artisanal bakery bread and fresh wholesome food packed neatly '
                'into eco-friendly kraft boxes',
          ),
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good food deserves another destination.',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 31,
            height: 1.18,
            letterSpacing: -0.025 * 31,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
            color: OnboardingColors.heading,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Share safe surplus food with people nearby instead of letting it '
          'go to waste.',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 400)],
            color: OnboardingColors.body,
          ),
        ),
      ],
    );
  }
}
