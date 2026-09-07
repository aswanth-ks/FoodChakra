import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/onboarding_widgets.dart';

/// Onboarding step 2 — "FoodLoop Onboarding — Turn Extra Food (Screen 3)".
///
/// Faithful translation of the Stitch design
/// (screen `ccb514b6ddfe44eeb589b84ce04230ea`).
class ShareSurplusScreen extends StatelessWidget {
  const ShareSurplusScreen({
    super.key,
    this.onContinue,
    this.onSkip,
    this.onSignIn,
  });

  /// Leads to onboarding step 3, which is not implemented yet.
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onSignIn;

  static const List<_Step> _steps = [
    _Step('01', Icons.inventory_2_outlined, 'SHARE', 'Tell us what you have.'),
    _Step('02', Icons.people_outline, 'CONNECT', 'Find people nearby.'),
    _Step('03', Icons.shopping_bag_outlined, 'RESCUE', 'Collect it in time.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              // Header and footer stay put; only the middle scrolls, so the
              // CTA is always reachable and short screens never overflow.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OnboardingSkipButton(onPressed: onSkip, compact: true),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          SizedBox(height: 4),
                          _Headline(),
                          SizedBox(height: 14),
                          _HeroPanel(),
                          SizedBox(height: 12),
                          _StepList(steps: _steps),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  const OnboardingPageIndicator(
                    count: 3,
                    activeIndex: 1,
                    dotSize: 6,
                    activeWidth: 24,
                    inactiveColor: OnboardingColors.dotInactiveAlt,
                  ),
                  const SizedBox(height: 20),
                  OnboardingPrimaryButton(
                    label: 'Continue',
                    fontSize: 15.5,
                    onPressed: onContinue,
                    shadow: const [
                      BoxShadow(
                        color: Color(0x4D183B2B),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OnboardingSignInPrompt(onSignIn: onSignIn, fontSize: 13.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turn extra food\ninto something useful.',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 30,
            height: 1.14,
            letterSpacing: -0.03 * 30,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
            color: OnboardingColors.heading,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Share what you have. FoodLoop helps connect it with people '
            'nearby before it becomes waste.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
              fontVariations: const [FontVariation('wght', 400)],
              color: OnboardingColors.body,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero photo with a bottom-aligned glass "Available nearby" card.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: OnboardingColors.tintSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xCCE3EBE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A183B2B),
            blurRadius: 24,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/onboarding_share.jpg',
              fit: BoxFit.cover,
              semanticLabel:
                  'Wholesome fresh meals neatly packed into eco-friendly '
                  'containers',
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x66000000), Color(0x00000000)],
                  stops: [0, 0.5],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: _AvailabilityCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A142018),
            blurRadius: 16,
            spreadRadius: -2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: OnboardingColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Flexible so the label ellipsises rather than overflowing
                    // the card on narrow phones.
                    Flexible(
                      child: Text(
                        'AVAILABLE NEARBY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                          letterSpacing: 0.8,
                          color: OnboardingColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '40 servings ready to share',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation('wght', 600)],
                    color: OnboardingColors.heading,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: OnboardingColors.chipSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x99DCE6E0)),
            ),
            child: Text(
              'Today',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontVariations: const [FontVariation('wght', 500)],
                color: OnboardingColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step {
  const _Step(this.number, this.icon, this.title, this.description);

  final String number;
  final IconData icon;
  final String title;
  final String description;
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps});

  final List<_Step> steps;

  @override
  Widget build(BuildContext context) {
    const hairline = BorderSide(color: OnboardingColors.hairline);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: hairline, bottom: hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: OnboardingColors.hairline),
            _StepRow(step: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: OnboardingColors.tintSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              step.number,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation('wght', 600)],
                letterSpacing: 0.6,
                color: OnboardingColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: OnboardingColors.canvas,
              shape: BoxShape.circle,
              border: Border.all(color: OnboardingColors.chipBorder),
            ),
            child: Icon(step.icon, size: 16, color: OnboardingColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation('wght', 600)],
                    letterSpacing: 0.8,
                    color: OnboardingColors.heading,
                  ),
                ),
                const SizedBox(width: 12),
                // Expanded (not Spacer) so the description can shrink on
                // narrow screens instead of overflowing the row.
                Expanded(
                  child: Text(
                    step.description,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontVariations: const [FontVariation('wght', 400)],
                      color: OnboardingColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
