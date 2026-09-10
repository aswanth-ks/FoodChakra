import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';

/// FoodLoop splash screen.
///
/// A faithful translation of the Stitch design
/// (`FoodLoop Mobile Design System` / `FoodLoop Splash Screen`).
///
/// The design's status bar and home-indicator are device chrome mockups — the
/// operating system draws those, so they are deliberately not reproduced.
///
/// The design specifies no hold duration, so a short one is used to let the
/// reveal be seen. When it ends the screen reports that it is done and stops
/// there: the router's authentication gate chooses the destination, once the
/// session restore has also settled. A returning user therefore never sees
/// onboarding, and a slow restore is waited for here rather than flickering
/// through a sign-in screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onComplete});

  /// Called once the entrance animation has finished and rested. It reports
  /// only that the animation is over — never where to go — so this screen
  /// stays navigation-agnostic and testable without a router.
  final VoidCallback? onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Total timeline: the last element starts at 380ms and runs for 700ms.
  static const Duration _timeline = Duration(milliseconds: 1080);

  /// Each element animates for 700ms of the shared timeline.
  static const double _elementSpan = 700 / 1080;

  /// `cubic-bezier(0.16, 1, 0.3, 1)` from the design.
  static const Curve _easing = Cubic(0.16, 1, 0.3, 1);

  /// How long the finished composition rests before advancing.
  static const Duration _hold = Duration(milliseconds: 600);

  late final AnimationController _controller;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkOffset;
  late final Animation<double> _taglineOpacity;

  bool _started = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _timeline);

    // Start times from the design: logo 50ms, wordmark 200ms, tagline 380ms.
    _logoOpacity = _fade(startMs: 50);
    _logoScale = Tween<double>(begin: 0.92, end: 1).animate(_interval(50));
    _wordmarkOpacity = _fade(startMs: 200);
    _wordmarkOffset = Tween<double>(begin: 6, end: 0).animate(_interval(200));
    _taglineOpacity = _fade(startMs: 380);
  }

  void _scheduleAdvance() {
    _advanceTimer = Timer(_timeline + _hold, () {
      if (mounted) widget.onComplete?.call();
    });
  }

  CurvedAnimation _interval(int startMs) {
    final begin = startMs / _timeline.inMilliseconds;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(
        begin,
        (begin + _elementSpan).clamp(0.0, 1.0),
        curve: _easing,
      ),
    );
  }

  Animation<double> _fade({required int startMs}) =>
      Tween<double>(begin: 0, end: 1).animate(_interval(startMs));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The design shows everything immediately when reduced motion is requested.
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _scheduleAdvance();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          // Keeps the composition intact on very short screens instead of
          // overflowing.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutterMobile,
          ),
          child: Transform.translate(
            // `-translate-y-6` — optically centres the mark above true centre.
            offset: const Offset(0, -AppSpacing.xl),
            child: ConstrainedBox(
              // Tailwind `max-w-sm`.
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedLogo(opacity: _logoOpacity, scale: _logoScale),
                  const SizedBox(height: AppSpacing.xl),
                  _AnimatedWordmark(
                    opacity: _wordmarkOpacity,
                    offset: _wordmarkOffset,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Rescue food. Reduce waste.',
                      textAlign: TextAlign.center,
                      style: AppTypography.splashTagline,
                    ),
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

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({required this.opacity, required this.scale});

  final Animation<double> opacity;
  final Animation<double> scale;

  /// `w-14 h-14` — 56 logical pixels.
  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: SvgPicture.asset(
          'assets/brand/foodloop_logo.svg',
          width: _size,
          height: _size,
          semanticsLabel: 'FoodLoop logo',
        ),
      ),
    );
  }
}

class _AnimatedWordmark extends StatelessWidget {
  const _AnimatedWordmark({required this.opacity, required this.offset});

  final Animation<double> opacity;
  final Animation<double> offset;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: AnimatedBuilder(
        animation: offset,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, offset.value), child: child),
        child: Text('FoodLoop', style: AppTypography.splashWordmark),
      ),
    );
  }
}
