import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/onboarding_widgets.dart';

/// Onboarding step 3 — "FoodLoop Onboarding — Every Rescue Counts".
///
/// Faithful translation of the Stitch design
/// (screen `2d98bc1215e347cfb850e70725115000`).
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({
    super.key,
    this.onStartRescuing,
    this.onSkip,
    this.onSignIn,
  });

  /// Leads past onboarding. No destination until auth exists (Phase 3).
  final VoidCallback? onStartRescuing;
  final VoidCallback? onSkip;
  final VoidCallback? onSignIn;

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen>
    with SingleTickerProviderStateMixin {
  static const Curve _easing = Cubic(0.16, 1, 0.3, 1);

  late final AnimationController _controller;
  late final Animation<double> _ring;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    // The design draws the ring to 75%.
    _ring = Tween<double>(
      begin: 0,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: _easing));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OnboardingSkipButton(onPressed: widget.onSkip, compact: true),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          const _Headline(),
                          const SizedBox(height: 20),
                          Center(child: _ImpactRing(progress: _ring)),
                          const SizedBox(height: 24),
                          const _MetricRow(),
                          const SizedBox(height: 16),
                          Text(
                            'Small actions add up.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              fontVariations: const [
                                FontVariation('wght', 500),
                              ],
                              color: OnboardingColors.skipAlt,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  const OnboardingPageIndicator(
                    count: 3,
                    activeIndex: 2,
                    dotSize: 8,
                    activeWidth: 24,
                    spacing: 6,
                    inactiveColor: OnboardingColors.dotInactiveImpact,
                  ),
                  const SizedBox(height: 16),
                  OnboardingPrimaryButton(
                    label: 'Start rescuing',
                    fontSize: 15.5,
                    onPressed: widget.onStartRescuing,
                    shadow: const [
                      BoxShadow(
                        color: Color(0x2E183B2B),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OnboardingSignInPrompt(
                    onSignIn: widget.onSignIn,
                    fontSize: 13,
                    promptColor: OnboardingColors.muted,
                    linkColor: OnboardingColors.heading,
                  ),
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
          'Every rescue counts.',
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 325),
          child: Text(
            'See the difference your food rescues can make for people, '
            'communities, and the planet.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14.5,
              height: 1.48,
              fontWeight: FontWeight.w400,
              fontVariations: const [FontVariation('wght', 400)],
              color: OnboardingColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular progress ring with the headline impact figure at its centre.
class _ImpactRing extends StatelessWidget {
  const _ImpactRing({required this.progress});

  final Animation<double> progress;

  static const double _size = 210;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) => CustomPaint(
              size: const Size.square(_size),
              painter: _RingPainter(progress.value),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FOOD RESCUED',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation('wght', 600)],
                  letterSpacing: 0.08 * 11,
                  color: OnboardingColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: '12.4 ',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 38,
                    height: 1,
                    letterSpacing: -0.03 * 38,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                    color: OnboardingColors.forest,
                  ),
                  children: [
                    TextSpan(
                      text: 'kg',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation('wght', 600)],
                        color: OnboardingColors.forest.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Example impact',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontVariations: const [FontVariation('wght', 500)],
                  color: OnboardingColors.skipAlt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // The design uses r=90 in a 200 viewBox.
    final radius = size.width * (90 / 200);

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFF0F5F1));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (5 / 200)
        ..color = const Color(0xFFE3EBE5),
    );

    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // the design rotates the ring -90deg
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (7 / 200)
        ..strokeCap = StrokeCap.round
        ..color = OnboardingColors.forest,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _MetricCard(value: '24', label: 'Meals'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _MetricCard(value: '3.8', unit: 'kg', label: 'Food diverted'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _MetricCard(value: '1', label: 'Rescue'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label, this.unit});

  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99E3EBE5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 20,
                height: 1.1,
                letterSpacing: -0.01 * 20,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                color: OnboardingColors.heading,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                      color: OnboardingColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 500)],
              color: OnboardingColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
