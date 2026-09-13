import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;

import '../../../app/theme/app_typography.dart';
import '../../../core/map/foodloop_map.dart';
import '../../../core/map/geo_point.dart';
import '../../../core/error/failures.dart';

/// Picks the point a rescuer will travel to.
///
/// The Give flow collects a place *name* ("Community Hall"), which is useful
/// to a human and useless to a geospatial query. This screen is where the
/// listing gets the coordinate Explore actually searches on.
///
/// Nothing is saved by panning. The map moving is not a decision — the user
/// scrolling past a street is not them choosing it — so the selection only
/// changes on a deliberate tap, and only leaves this screen when they press
/// "Use this location".
///
/// Plain parameters and no providers: the connector owns the data.
class PickupLocationScreen extends StatefulWidget {
  const PickupLocationScreen({
    super.key,
    this.center,
    this.currentLocation,
    this.initialSelection,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onBack,
    this.onConfirm,
    this.onUseMyLocation,
    this.locating = false,
    this.tileProvider,
  });

  /// Where the map opens. Null while it is still being worked out, or when it
  /// could not be — there is no default point, because a default point is a
  /// guess about where someone is.
  final GeoPoint? center;

  /// The device's own position, drawn as the "you" dot.
  final GeoPoint? currentLocation;

  /// A point chosen on a previous visit, so coming back does not lose it.
  final GeoPoint? initialSelection;

  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  /// Receives the confirmed point. Called once, on "Use this location".
  final void Function(GeoPoint point)? onConfirm;

  final VoidCallback? onUseMyLocation;
  final bool locating;

  final TileProvider? tileProvider;

  @override
  State<PickupLocationScreen> createState() => _PickupLocationScreenState();
}

class _PickupLocationScreenState extends State<PickupLocationScreen> {
  GeoPoint? _selected;

  @override
  void initState() {
    super.initState();
    // Opening on the device's position with it already selected is the common
    // case — most people share food from where they are. It is still a real
    // coordinate, and still has to be confirmed before it is used.
    _selected = widget.initialSelection ?? widget.center;
  }

  @override
  void didUpdateWidget(PickupLocationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The centre arriving late (the fix resolved after the shell was drawn)
    // seeds the selection, but never overwrites a choice already made.
    if (_selected == null && widget.center != null) {
      _selected = widget.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back, size: 20),
          color: const Color(0xFF142018),
          tooltip: 'Go back',
        ),
        title: Text(
          'Pickup location',
          style: _font(16, 700, const Color(0xFF142018)),
        ),
      ),
      // The shell is drawn immediately and only the map area waits. Wrapping
      // the page in a builder that waits for GPS would leave the user staring
      // at a blank screen with no way back.
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tap the map to set where rescuers should collect this food.',
                style: _font(
                  13.5,
                  400,
                  const Color(0xFF4F6355),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _mapArea(selected)),
              const SizedBox(height: 12),
              _SelectionSummary(point: selected),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  // Nothing to confirm until a real point is selected.
                  onPressed: selected == null || widget.onConfirm == null
                      ? null
                      : () => widget.onConfirm!(selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF183B2B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCFD8D2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Use this location',
                    style: _font(15.5, 600, Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapArea(GeoPoint? selected) {
    if (widget.error != null) {
      return _MapMessage(
        icon: Icons.location_off_outlined,
        title: "Couldn't get your location",
        body: widget.error is Failure
            ? (widget.error! as Failure).message
            : 'FoodLoop needs a starting point for the map. Check that '
                  'location is on, then try again.',
        actionLabel: 'Try again',
        onAction: widget.onRetry,
      );
    }

    final center = widget.center;
    if (widget.loading || center == null) {
      return const _MapMessage(
        icon: Icons.my_location,
        title: 'Finding your location',
        body: 'One moment.',
        busy: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => FoodLoopMap(
        center: center,
        zoom: 16,
        height: constraints.maxHeight,
        selected: selected,
        currentLocation: widget.currentLocation,
        onTapPoint: (point) => setState(() => _selected = point),
        onRecenter: widget.onUseMyLocation,
        recentering: widget.locating,
        tileProvider: widget.tileProvider,
      ),
    );
  }
}

/// Shows exactly which coordinate is about to be published, so the user can
/// see that it changed when they tapped.
class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({this.point});

  final GeoPoint? point;

  @override
  Widget build(BuildContext context) {
    final p = point;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EBE5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.place_outlined,
            size: 17,
            color: Color(0xFF183B2B),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              p == null ? 'No pickup point selected yet' : 'Pickup point: $p',
              style: _font(13, 500, const Color(0xFF2C3E33)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(icon, size: 26, color: const Color(0xFF183B2B)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _font(15, 700, const Color(0xFF142018)),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: _font(12.5, 400, const Color(0xFF768A7C), height: 1.45),
          ),
          if (label != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF183B2B),
              ),
              child: Text(label, style: _font(13.5, 600, const Color(0xFF183B2B))),
            ),
          ],
        ],
      ),
    );
  }
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
