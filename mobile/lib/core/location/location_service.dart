import 'package:geolocator/geolocator.dart';

/// Result of a location permission/fetch attempt.
enum LocationOutcome {
  /// Permission granted and a position was obtained.
  granted,

  /// The user declined the permission prompt this time.
  denied,

  /// The user declined permanently ("Don't ask again").
  deniedForever,

  /// Device location services (GPS) are turned off entirely.
  serviceDisabled,

  /// The platform call failed for any other reason — most commonly no
  /// location plugin channel is available (widget tests, an unsupported
  /// platform, or an emulator with no location provider configured). Callers
  /// treat this the same as a denial rather than crashing, so the user is
  /// never stranded on this screen.
  unavailable,
}

class LocationResult {
  const LocationResult(this.outcome, {this.position});

  final LocationOutcome outcome;
  final Position? position;

  bool get isGranted => outcome == LocationOutcome.granted;
}

/// Thin wrapper around `package:geolocator`.
///
/// This is the ONLY place in the app that imports geolocator. Screens depend
/// on this service, never the plugin directly, so the real platform call can
/// be swapped for a fake in tests.
class LocationService {
  const LocationService();

  /// Runs the real permission + fetch flow. Set your emulator's location
  /// under Extended Controls -> Location to see a real coordinate returned.
  Future<LocationResult> requestLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(LocationOutcome.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationOutcome.denied);
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } on Object {
        // A fresh fix can time out on a slow or emulated GPS provider.
        // A cached last-known position is still a real, useful result.
        position = await Geolocator.getLastKnownPosition();
        if (position == null) rethrow;
      }

      return LocationResult(LocationOutcome.granted, position: position);
    } catch (_) {
      // Covers MissingPluginException (no platform implementation, e.g. in
      // widget tests), a timeout with nothing cached, and anything else
      // unexpected. The caller decides how to proceed from here.
      return const LocationResult(LocationOutcome.unavailable);
    }
  }
}
