import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_providers.dart';
import '../../../core/map/geo_point.dart';
import '../../rescue/presentation/listing_providers.dart';
import 'pickup_location_screen.dart';

/// Connects [PickupLocationScreen] to the device's location.
///
/// The map has to open somewhere, and the only defensible somewhere is the
/// user's own position — so this waits on the same origin the rest of the app
/// uses rather than introducing a second idea of where "here" is.
class PickupLocationView extends ConsumerStatefulWidget {
  const PickupLocationView({
    super.key,
    this.initialSelection,
    this.onBack,
    this.onConfirm,
  });

  final GeoPoint? initialSelection;
  final VoidCallback? onBack;
  final void Function(GeoPoint point)? onConfirm;

  @override
  ConsumerState<PickupLocationView> createState() => _PickupLocationViewState();
}

class _PickupLocationViewState extends ConsumerState<PickupLocationView> {
  bool _locating = false;

  /// Re-reads the device position for the "use my location" button.
  ///
  /// Deliberately only on a press. Asking the platform on every rebuild is how
  /// a screen ends up re-prompting for permission and draining the radio.
  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final result = await ref.read(locationServiceProvider).requestLocation();
      final position = result.position;
      if (!result.isGranted || position == null || !mounted) return;

      ref.read(deviceLocationProvider.notifier).setFromPosition(position);
      // Invalidating the origin moves the map: the screen is rebuilt with the
      // new centre, and the picker seeds its selection from it.
      ref.invalidate(currentOriginProvider);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(currentOriginProvider);
    final point = origin.hasValue
        ? GeoPoint.tryFrom(origin.value!.latitude, origin.value!.longitude)
        : null;

    return PickupLocationScreen(
      center: point,
      currentLocation: point,
      initialSelection: widget.initialSelection,
      loading: origin.isLoading,
      error: origin.error,
      onRetry: () => ref.invalidate(currentOriginProvider),
      onBack: widget.onBack,
      onConfirm: widget.onConfirm,
      onUseMyLocation: _useMyLocation,
      locating: _locating,
    );
  }
}
