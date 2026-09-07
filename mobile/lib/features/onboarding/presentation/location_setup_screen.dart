import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import '../../../core/location/location_service.dart';

/// "FoodLoop Location Setup Screen".
///
/// Faithful translation of the Stitch design
/// (screen `cce80807fdbe43e28fe84d970260b8f4`).
///
/// "Enable location" triggers the real Android/iOS permission prompt through
/// [LocationService] — set the emulator's location under Extended Controls ->
/// Location to see a real coordinate returned. Whatever the outcome (granted,
/// denied, or the plugin being unavailable, e.g. in a test), [onContinue]
/// still fires so the user is never stranded on this screen; only the
/// snackbar shown differs.
class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({
    super.key,
    this.onBack,
    this.onContinue,
    this.locationService = const LocationService(),
  });

  final VoidCallback? onBack;

  /// Called once the user has moved past this screen, by any of the three
  /// exits (Skip, Not now, or a resolved Enable-location attempt).
  final void Function(LocationOutcome outcome)? onContinue;

  final LocationService locationService;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A looping pulse is decorative; skip it entirely under reduced motion.
    if (!MediaQuery.disableAnimationsOf(context) && !_radar.isAnimating) {
      _radar.repeat();
    }
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  Future<void> _enableLocation() async {
    setState(() => _requesting = true);
    final result = await widget.locationService.requestLocation();
    if (!mounted) return;
    setState(() => _requesting = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(_messageFor(result))));
    widget.onContinue?.call(result.outcome);
  }

  String _messageFor(LocationResult result) => switch (result.outcome) {
    LocationOutcome.granted =>
      result.position != null
          ? 'Location enabled '
                '(${result.position!.latitude.toStringAsFixed(4)}, '
                '${result.position!.longitude.toStringAsFixed(4)}).'
          : 'Location enabled.',
    LocationOutcome.denied => 'Location permission was not granted.',
    LocationOutcome.deniedForever =>
      'Location is blocked. You can enable it later in system settings.',
    LocationOutcome.serviceDisabled =>
      'Turn on device location to use this feature.',
    LocationOutcome.unavailable => 'Could not get your location right now.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LocationColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 410),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    onBack: widget.onBack,
                    onSkip: () =>
                        widget.onContinue?.call(LocationOutcome.denied),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _MapCard(radar: _radar),
                          const SizedBox(height: 28),
                          const _TextBlock(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EnableLocationButton(
                    loading: _requesting,
                    onPressed: _requesting ? null : _enableLocation,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _requesting
                        ? null
                        : () => widget.onContinue?.call(LocationOutcome.denied),
                    style: TextButton.styleFrom(
                      foregroundColor: LocationColors.inkMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Not now',
                      style: _font(14, 500, LocationColors.inkMuted),
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

/// Palette from the design's Tailwind config.
class LocationColors {
  const LocationColors._();

  static const Color brand = Color(0xFF183B2B);
  static const Color brandHover = Color(0xFF132F22);
  static const Color brandLight = Color(0xFFF0F5F1);
  static const Color brandSage = Color(0xFFE3EBE5);
  static const Color brandSubtle = Color(0xFF8BA695);

  static const Color surface = Color(0xFFFAF9F6);
  static const Color surfaceDim = Color(0xFFF4F3F0);
  static const Color card = Color(0xFFFFFFFF);

  static const Color inkPrimary = Color(0xFF142018);
  static const Color inkSecondary = Color(0xFF4F6355);
  static const Color inkMuted = Color(0xFF768A7C);
  static const Color inkFaint = Color(0xFF9EAEA2);

  static const Color mapBase = Color(0xFFF2F1EC);
  static const Color mapBorder = Color(0xFFE8E6DF);
  static const Color mapZone = Color(0xFFECE9DF);
  static const Color mapPark = Color(0xFFE5EAE5);
}

TextStyle _font(double size, int weight, Color color, {double? height}) =>
    TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
    );

class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, this.onSkip});

  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 20),
          color: LocationColors.inkPrimary,
          tooltip: 'Go back',
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: LocationColors.inkSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          child: Text(
            'Skip',
            style: _font(13.5, 500, LocationColors.inkSecondary),
          ),
        ),
      ],
    );
  }
}

/// The abstract "rescue network" map illustration.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.radar});

  final Animation<double> radar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: LocationColors.mapBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LocationColors.mapBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A142018),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter())),

            // Coverage rings around the user.
            Center(
              child: Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LocationColors.brand.withValues(alpha: 0.02),
                  border: Border.all(
                    color: LocationColors.brand.withValues(alpha: 0.20),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LocationColors.brand.withValues(alpha: 0.03),
                      border: Border.all(
                        color: LocationColors.brand.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Radar pulse.
            Center(
              child: AnimatedBuilder(
                animation: radar,
                builder: (context, _) {
                  final t = radar.value;
                  return Opacity(
                    opacity: (1 - t) * 0.20,
                    child: Container(
                      width: 56 * (1 + t * 1.6),
                      height: 56 * (1 + t * 1.6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: LocationColors.brand,
                      ),
                    ),
                  );
                },
              ),
            ),

            const Center(child: _UserMarker()),

            const Positioned(
              top: 52,
              right: 78,
              child: _OpportunityMarker(distance: '400m', primary: true),
            ),
            const Positioned(
              top: 82,
              left: 74,
              child: _OpportunityMarker(
                distance: '650m',
                dotColor: Color(0xFF345945),
              ),
            ),
            const Positioned(
              bottom: 44,
              left: 88,
              child: _OpportunityMarker(
                distance: '800m',
                dotColor: Color(0xFF274E3A),
              ),
            ),
            Positioned(
              bottom: 66,
              right: 62,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: LocationColors.brandSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for the stylised zones, park and road network.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The design's SVG uses a 360x270 viewBox with `slice` scaling.
    final scale = size.width / 360 > size.height / 270
        ? size.width / 360
        : size.height / 270;
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 270 * scale) / 2,
    );
    canvas.scale(scale);

    void zone(double x, double y, double w, double h, double opacity) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(16),
        ),
        Paint()..color = LocationColors.mapZone.withValues(alpha: opacity),
      );
    }

    zone(18, 22, 130, 96, 0.60);
    zone(190, 30, 150, 74, 0.45);
    zone(22, 160, 146, 88, 0.45);
    zone(200, 145, 140, 105, 0.60);

    // Park / green buffer.
    canvas.drawPath(
      Path()
        ..moveTo(-10, 110)
        ..cubicTo(40, 100, 70, 120, 110, 115)
        ..cubicTo(130, 112, 140, 90, 130, 60)
        ..lineTo(-10, 60)
        ..close(),
      Paint()..color = LocationColors.mapPark.withValues(alpha: 0.5),
    );

    Paint road(double width) => Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // Major diagonal avenue.
    final avenue = Path()
      ..moveTo(-20, 200)
      ..cubicTo(90, 190, 140, 170, 200, 120)
      ..cubicTo(270, 65, 310, 50, 390, 40);
    canvas.drawPath(avenue, road(16));

    // Grid arteries.
    canvas.drawLine(const Offset(175, -10), const Offset(175, 290), road(13));
    canvas.drawLine(const Offset(60, -10), const Offset(60, 290), road(8));
    canvas.drawLine(const Offset(300, -10), const Offset(300, 290), road(9));
    canvas.drawLine(const Offset(-10, 80), const Offset(370, 80), road(9));
    canvas.drawLine(const Offset(-10, 215), const Offset(370, 215), road(8));

    // Neighbourhood connectors.
    canvas.drawPath(
      Path()
        ..moveTo(60, 80)
        ..cubicTo(110, 80, 140, 120, 175, 145),
      road(7),
    );
    canvas.drawPath(
      Path()
        ..moveTo(175, 145)
        ..cubicTo(230, 180, 260, 170, 300, 215),
      road(7),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E142018),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: LocationColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6E8E6)),
          ),
          child: Text('You', style: _font(9.5, 600, LocationColors.brand)),
        ),
      ],
    );
  }
}

/// A nearby rescue opportunity: pin plus a distance pill.
class _OpportunityMarker extends StatelessWidget {
  const _OpportunityMarker({
    required this.distance,
    this.primary = false,
    this.dotColor,
  });

  final String distance;
  final bool primary;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LocationColors.brand,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D183B2B),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          _DistancePill(distance: distance, showDot: true),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: dotColor ?? LocationColors.brand,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE0ECE3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            distance,
            style: _font(9.5, 500, LocationColors.inkSecondary),
          ),
        ),
      ],
    );
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.distance, this.showDot = false});

  final String distance;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDFE5E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F142018),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF059669),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(distance, style: _font(10.5, 600, LocationColors.inkPrimary)),
        ],
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
          'Find food worth\nrescuing near you',
          style: _font(
            28,
            700,
            LocationColors.inkPrimary,
            height: 1.18,
          ).copyWith(letterSpacing: -0.025 * 28),
        ),
        const SizedBox(height: 12),
        Text(
          'FoodLoop uses your location to show available food nearby, '
          'calculate pickup distances, and connect you with the right rescue '
          'opportunities.',
          style: _font(
            14,
            400,
            LocationColors.inkSecondary,
            height: 1.55,
          ).copyWith(letterSpacing: -0.01 * 14),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: LocationColors.brand.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Your location is used only to power nearby rescue features.',
                style: _font(11.5, 400, LocationColors.inkMuted, height: 1.2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EnableLocationButton extends StatelessWidget {
  const _EnableLocationButton({this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E183B2B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: LocationColors.brand,
            foregroundColor: Colors.white,
            // The design shows an enabled button; keep its appearance while
            // the action is still unwired (Phase 13).
            disabledBackgroundColor: LocationColors.brand,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Enable location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _font(15.5, 600, Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
