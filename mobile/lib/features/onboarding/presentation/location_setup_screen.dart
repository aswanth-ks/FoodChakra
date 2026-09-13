import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_map/flutter_map.dart' show TileProvider;

import '../../../app/theme/app_typography.dart';
import '../../../core/location/location_service.dart';
import '../../../core/map/foodloop_map.dart';
import '../../../core/map/geo_point.dart';

/// "FoodLoop Location Setup Screen".
///
/// Faithful translation of the Stitch design
/// (screen `cce80807fdbe43e28fe84d970260b8f4`).
///
/// "Enable location" runs the real Android/iOS permission flow through
/// [LocationService]. Only a genuine fix moves the user on: every failure
/// keeps them here with the reason and a way to act on it, because continuing
/// as though location were available would leave the app hunting for nearby
/// food it has no coordinates for.
class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({
    super.key,
    this.onBack,
    this.onContinue,
    this.onLocationObtained,
    this.locationService = const LocationService(),
    this.tileProvider,
  });

  final VoidCallback? onBack;

  /// Called when the user leaves this screen: with [LocationOutcome.granted]
  /// after a real fix, or with [LocationOutcome.denied] when they dismiss the
  /// screen themselves via Skip or "Not now".
  ///
  /// A failed attempt does **not** call this. The user stays put with a retry.
  final void Function(LocationOutcome outcome)? onContinue;

  /// Receives the real position, before [onContinue] fires, so the coordinates
  /// reach application state rather than being shown once and discarded.
  final void Function(Position position)? onLocationObtained;

  final LocationService locationService;

  /// Overridden in tests so the map never reaches for a tile.
  final TileProvider? tileProvider;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;
  bool _requesting = false;

  /// The last unsuccessful outcome, or null when nothing has failed yet.
  /// Drives the in-screen explanation and the action offered with it.
  LocationOutcome? _issue;

  /// The real fix, once one has been taken. Null until then — and the map is
  /// not drawn until then either, because drawing one would mean choosing a
  /// centre, and the only honest centre is where the user actually is.
  GeoPoint? _fix;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _continueIfAlreadyGranted();
  }

  /// A user who granted permission on an earlier run should not be asked
  /// again. If a fix can be taken without prompting, this screen takes it and
  /// gets out of the way.
  Future<void> _continueIfAlreadyGranted() async {
    final readiness = await widget.locationService.readiness();
    if (!mounted || readiness != LocationReadiness.ready) return;

    final result = await widget.locationService.requestLocation();
    if (!mounted || !result.isGranted) return;
    _accept(result, silent: true);
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
    setState(() {
      _requesting = true;
      _issue = null;
    });
    final result = await widget.locationService.requestLocation();
    if (!mounted) return;
    setState(() => _requesting = false);

    if (result.isGranted) {
      _accept(result);
      return;
    }

    // Nothing is reported as enabled here, and no placeholder coordinate is
    // invented: the user stays on this screen until a real fix arrives.
    setState(() => _issue = result.outcome);
  }

  /// Records the real coordinates and shows them on the map.
  ///
  /// [silent] is the returning-user path: permission was granted on an earlier
  /// run, so the fix is taken without a prompt and the screen gets out of the
  /// way rather than making the user confirm the same thing twice. Only a
  /// fresh grant stops to show the map.
  void _accept(LocationResult result, {bool silent = false}) {
    final position = result.position;
    if (position != null) {
      // Handed over immediately, so the coordinates are application state from
      // the moment they exist rather than something this screen is holding.
      widget.onLocationObtained?.call(position);
    }

    if (silent || position == null) {
      widget.onContinue?.call(LocationOutcome.granted);
      return;
    }

    final point = GeoPoint.tryFrom(position.latitude, position.longitude);
    if (point == null) {
      // The platform gave a coordinate no map can place. Nothing is invented
      // to cover for it: the user is told, and can try again.
      setState(() => _issue = LocationOutcome.unavailable);
      return;
    }
    setState(() => _fix = point);
  }

  /// What went wrong, in the user's terms.
  static String _issueMessage(LocationOutcome outcome) => switch (outcome) {
    LocationOutcome.denied =>
      'FoodLoop needs your location to find surplus food near you.',
    LocationOutcome.deniedForever =>
      'Location is blocked for FoodLoop. Grant it in Settings to find '
          'surplus food near you.',
    LocationOutcome.serviceDisabled => 'Turn on Location to continue.',
    LocationOutcome.timedOut =>
      "Couldn't get your location. GPS can be slow indoors — try again, or "
          'step near a window.',
    LocationOutcome.unavailable =>
      'Could not get your location. Please try again.',
    LocationOutcome.granted => '',
  };

  /// The label of the action offered alongside the message, or null when a
  /// plain retry is all that is useful.
  static String? _issueActionLabel(LocationOutcome outcome) =>
      switch (outcome) {
        LocationOutcome.deniedForever => 'Open settings',
        LocationOutcome.serviceDisabled => 'Open location settings',
        _ => null,
      };

  Future<void> _runIssueAction(LocationOutcome outcome) async {
    // Neither of these can grant anything by itself — Android alone decides —
    // so the screen stays put and the user retries after coming back.
    switch (outcome) {
      case LocationOutcome.deniedForever:
        await widget.locationService.openAppSettings();
      case LocationOutcome.serviceDisabled:
        await widget.locationService.openLocationSettings();
      default:
        break;
    }
  }

  /// Re-reads the device position from the map's "use my location" button.
  Future<void> _recenter() async {
    setState(() => _requesting = true);
    final result = await widget.locationService.requestLocation();
    if (!mounted) return;
    setState(() => _requesting = false);

    final position = result.position;
    if (!result.isGranted || position == null) {
      setState(() => _issue = result.outcome);
      return;
    }
    widget.onLocationObtained?.call(position);
    final point = GeoPoint.tryFrom(position.latitude, position.longitude);
    if (point != null) setState(() => _fix = point);
  }

  @override
  Widget build(BuildContext context) {
    final issue = _issue;
    final fix = _fix;
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
                          // Before a fix there is nothing real to centre a map
                          // on, so the design's illustration stands in. The
                          // moment a real position exists it is replaced by
                          // the real map at that position.
                          if (fix == null)
                            _MapCard(radar: _radar)
                          else
                            FoodLoopMap(
                              center: fix,
                              currentLocation: fix,
                              zoom: 16,
                              height: 250,
                              onRecenter: _recenter,
                              recentering: _requesting,
                              tileProvider: widget.tileProvider,
                            ),
                          if (fix != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Location set ($fix).',
                              style: _font(12, 500, LocationColors.inkMuted),
                            ),
                          ],
                          const SizedBox(height: 28),
                          const _TextBlock(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (issue != null) ...[
                    _IssueNotice(
                      message: _issueMessage(issue),
                      actionLabel: _issueActionLabel(issue),
                      onAction: () => _runIssueAction(issue),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _EnableLocationButton(
                    loading: _requesting && fix == null,
                    label: switch ((fix, issue)) {
                      (_?, _) => 'Continue',
                      (_, null) => 'Enable location',
                      _ => 'Try again',
                    },
                    onPressed: _requesting
                        ? null
                        : (fix != null
                              ? () => widget.onContinue?.call(
                                  LocationOutcome.granted,
                                )
                              : _enableLocation),
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

/// Explains a failed attempt and offers the one action that can resolve it.
class _IssueNotice extends StatelessWidget {
  const _IssueNotice({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: LocationColors.brandLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LocationColors.brandSage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 16,
                color: LocationColors.brand.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: _font(
                    13,
                    500,
                    LocationColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (label != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: LocationColors.brand,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(label, style: _font(13, 600, LocationColors.brand)),
              ),
            ),
          ],
        ],
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
  const _EnableLocationButton({
    this.onPressed,
    this.loading = false,
    this.label = 'Enable location',
  });

  final VoidCallback? onPressed;
  final bool loading;

  /// Becomes "Try again" once an attempt has failed.
  final String label;

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
                        label,
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
