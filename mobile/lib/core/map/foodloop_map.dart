import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/app_typography.dart';
import 'geo_point.dart';

/// A pin the map should draw.
class MapPin {
  const MapPin({
    required this.point,
    required this.id,
    this.label,
    this.onTap,
  });

  /// Already validated — [GeoPoint] is the only way to build one.
  final GeoPoint point;

  /// Identifies what the pin stands for. For a listing this is its real
  /// backend id, so a tap can open that listing and no other.
  final String id;

  final String? label;
  final VoidCallback? onTap;
}

/// The one map in FoodLoop.
///
/// Every screen that shows a map uses this: location setup, the pickup-point
/// picker and Explore. Keeping it in one place is what stops three different
/// tile URLs, three attribution lines and three subtly different ideas of
/// which coordinate is which.
///
/// It renders whatever it is given and reports taps. It holds no location
/// state, asks for no permissions and calls no platform APIs — the caller owns
/// all of that, so this widget can be pumped in a test with no plugins at all.
class FoodLoopMap extends StatefulWidget {
  const FoodLoopMap({
    super.key,
    required this.center,
    this.zoom = 15,
    this.selected,
    this.currentLocation,
    this.pins = const [],
    this.onTapPoint,
    this.onRecenter,
    this.recentering = false,
    this.height = 280,
    this.interactive = true,
    this.tileProvider,
  });

  /// Where the map opens. Non-null on purpose: a map has to be somewhere, and
  /// "somewhere" must be a real point the caller obtained, never a default
  /// city this code picked.
  final GeoPoint center;

  final double zoom;

  /// The point the user has chosen, drawn as the selection pin.
  final GeoPoint? selected;

  /// The device's own position, drawn as the blue "you" dot. Null until a real
  /// fix exists.
  final GeoPoint? currentLocation;

  /// Additional pins — listings on Explore.
  final List<MapPin> pins;

  /// Called with the tapped coordinate. Null makes the map read-only.
  final void Function(GeoPoint point)? onTapPoint;

  /// Shows the "use my location" button when non-null.
  final VoidCallback? onRecenter;

  /// Swaps that button for a spinner while a fix is being taken.
  final bool recentering;

  final double height;
  final bool interactive;

  /// Overridden in tests so no tile is ever fetched over the network.
  final TileProvider? tileProvider;

  /// OpenStreetMap's standard tile layer. No API key, and none invented.
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Required by the OSM tile usage policy, which asks for an identifying
  /// User-Agent rather than the default one.
  static const String userAgentPackageName = 'com.foodloop.app';

  @override
  State<FoodLoopMap> createState() => _FoodLoopMapState();
}

class _FoodLoopMapState extends State<FoodLoopMap> {
  final MapController _controller = MapController();

  /// Tracks what the map was last told to show, so a rebuild that changes the
  /// centre moves the camera without re-creating the map.
  late GeoPoint _shown = widget.center;

  @override
  void didUpdateWidget(FoodLoopMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.center != _shown) {
      _shown = widget.center;
      // After the frame: the controller is only usable once the map is laid
      // out, and this can run during a build triggered by the parent.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.move(
            LatLng(widget.center.latitude, widget.center.longitude),
            _controller.camera.zoom,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onTapPoint = widget.onTapPoint;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: LatLng(
                  widget.center.latitude,
                  widget.center.longitude,
                ),
                initialZoom: widget.zoom,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
                onTap: onTapPoint == null
                    ? null
                    : (_, latLng) {
                        // Routed through GeoPoint so a coordinate the map
                        // considers valid but the API would reject never
                        // reaches a request.
                        final point = GeoPoint.tryFrom(
                          latLng.latitude,
                          latLng.longitude,
                        );
                        if (point != null) onTapPoint(point);
                      },
              ),
              children: [
                TileLayer(
                  urlTemplate: FoodLoopMap.tileUrl,
                  userAgentPackageName: FoodLoopMap.userAgentPackageName,
                  tileProvider: widget.tileProvider,
                  // A tile that will not load leaves a gap rather than an
                  // error: a missing square of map is survivable, a thrown
                  // exception takes the screen with it.
                  errorTileCallback: (_, _, _) {},
                ),
                MarkerLayer(markers: _markers()),
              ],
            ),
            const Positioned(bottom: 0, right: 0, child: _OsmAttribution()),
            if (widget.onRecenter != null)
              Positioned(
                top: 10,
                right: 10,
                child: _RecenterButton(
                  busy: widget.recentering,
                  onPressed: widget.recentering ? null : widget.onRecenter,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];

    final current = widget.currentLocation;
    if (current != null) {
      markers.add(
        Marker(
          key: const ValueKey('map-current-location'),
          point: LatLng(current.latitude, current.longitude),
          width: 26,
          height: 26,
          child: const _CurrentLocationDot(),
        ),
      );
    }

    for (final pin in widget.pins) {
      markers.add(
        Marker(
          key: ValueKey('map-pin-${pin.id}'),
          point: LatLng(pin.point.latitude, pin.point.longitude),
          width: 40,
          height: 46,
          // Anchored at the tip, so the pin points at its coordinate rather
          // than sitting centred half a pin north of it.
          alignment: Alignment.topCenter,
          child: _ListingPin(pin: pin),
        ),
      );
    }

    final selected = widget.selected;
    if (selected != null) {
      markers.add(
        Marker(
          key: const ValueKey('map-selected'),
          point: LatLng(selected.latitude, selected.longitude),
          width: 40,
          height: 46,
          alignment: Alignment.topCenter,
          child: const _SelectedPin(),
        ),
      );
    }

    return markers;
  }
}

/// Required by the OpenStreetMap copyright terms, and deliberately not
/// dismissible.
class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.white.withValues(alpha: 0.82),
      child: Text(
        '© OpenStreetMap contributors',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4F6355),
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.busy, this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Tooltip(
                  message: 'Use my location',
                  child: Icon(
                    Icons.my_location,
                    size: 19,
                    color: Color(0xFF183B2B),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your location',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8).withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedPin extends StatelessWidget {
  const _SelectedPin();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Selected location',
      child: const Icon(Icons.location_on, size: 40, color: Color(0xFF183B2B)),
    );
  }
}

class _ListingPin extends StatelessWidget {
  const _ListingPin({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pin.onTap,
      child: Semantics(
        button: pin.onTap != null,
        label: pin.label ?? 'Food listing',
        child: const Icon(
          Icons.location_on,
          size: 36,
          color: Color(0xFF2F6B4F),
        ),
      ),
    );
  }
}
