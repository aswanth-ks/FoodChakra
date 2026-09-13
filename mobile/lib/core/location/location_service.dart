import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../diagnostics/perf_trace.dart';

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

  /// Nothing came back within [LocationService.overallTimeout].
  ///
  /// Distinct from [unavailable] because it is the one outcome where trying
  /// again is genuinely likely to work: indoors, a first fix can simply take
  /// longer than anyone should be made to wait.
  timedOut,
}

class LocationResult {
  const LocationResult(this.outcome, {this.position});

  final LocationOutcome outcome;
  final Position? position;

  bool get isGranted => outcome == LocationOutcome.granted;
}

/// Whether a real fix can be taken right now, asked without prompting.
///
/// Used to decide whether the location onboarding screen is worth showing at
/// all. [unknown] is deliberately distinct from [needsSetup]: it means the
/// platform could not be asked (no plugin channel in a widget test, an
/// unsupported platform), which is not evidence that the user has refused
/// anything, so callers let it pass rather than blocking the app on it.
enum LocationReadiness { ready, needsSetup, unknown }

/// Thin wrapper around `package:geolocator`.
///
/// This is the ONLY place in the app that imports geolocator. Screens depend
/// on this service, never the plugin directly, so the real platform call can
/// be swapped for a fake in tests.
class LocationService {
  const LocationService();

  /// The longest the hardware parts of the sequence may take, in total.
  ///
  /// Every geolocator call needs a bound, not just the fix:
  /// `isLocationServiceEnabled`, `checkPermission` and `getLastKnownPosition`
  /// all cross a platform channel and none of them promises to return. One
  /// hung call would otherwise leave every screen that asks "where am I"
  /// waiting forever, which is exactly the infinite spinner these bounds exist
  /// to make impossible.
  ///
  /// The permission *prompt* is excluded, because it waits on a person rather
  /// than on hardware. See [_request].
  static const Duration overallTimeout = Duration(seconds: 10);

  /// How long to wait for a *fresh* fix before falling back to the last known
  /// one. Shorter than [overallTimeout] on purpose, so there is time left to
  /// use the fallback.
  static const Duration fixTimeout = Duration(seconds: 6);

  /// Reports whether permission and device location are already in place.
  ///
  /// Never shows a prompt: this only reads existing state, so a user who
  /// granted permission on a previous run is not asked a second time.
  Future<LocationReadiness> readiness() async {
    try {
      return await _readiness().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Includes the timeout. `unknown` is the right answer: a platform that
      // will not say is not evidence the user refused anything, and the
      // router lets it pass rather than blocking the app on it.
      return LocationReadiness.unknown;
    }
  }

  Future<LocationReadiness> _readiness() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationReadiness.needsSetup;
    }
    final permission = await Geolocator.checkPermission();
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationReadiness.ready,
      _ => LocationReadiness.needsSetup,
    };
  }

  /// Opens this app's system settings page, so a user who chose "Don't ask
  /// again" can grant the permission by hand. Android gives no other route
  /// back — the prompt is never shown again from inside the app.
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the device's location settings, for when GPS itself is off. The
  /// app cannot switch the radio on: only the user can.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Runs the real permission + fetch flow. Set your emulator's location
  /// under Extended Controls -> Location to see a real coordinate returned.
  /// Runs the real permission + fetch flow, bounded by [overallTimeout].
  ///
  /// Always completes. Every exit is a [LocationResult] — no path throws and
  /// no path hangs, because Home and Explore both wait on this.
  Future<LocationResult> requestLocation() async {
    try {
      return await PerfTrace.span('GPS requestLocation', _request);
    } on TimeoutException {
      return const LocationResult(LocationOutcome.timedOut);
    } catch (_) {
      // Covers MissingPluginException (no platform implementation, e.g. in
      // widget tests) and anything else unexpected. The caller decides how to
      // proceed from here.
      return const LocationResult(LocationOutcome.unavailable);
    }
  }

  Future<LocationResult> _request() async {
    // Bounded, because these three talk to hardware and a platform channel
    // can fail to answer.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
      const Duration(seconds: 3),
    );
    if (!serviceEnabled) {
      return const LocationResult(LocationOutcome.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 3),
    );
    if (permission == LocationPermission.denied) {
      // Deliberately NOT bounded. This one waits on a person reading a
      // dialog, and people are entitled to take their time. It used to sit
      // inside a ten-second budget, so an unhurried user became a "timeout" —
      // a retryable failure, which the provider layer duly retried, which
      // raised the dialog again. That loop was the worst thing in the app.
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
      // Only the fix itself is on the clock now, which is the part that is
      // genuinely waiting on hardware.
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: fixTimeout,
        ),
      ).timeout(fixTimeout);
    } on Object {
      // A fresh fix can time out indoors or on a slow provider. A cached
      // last-known position is still a real reading, and a recent one beats
      // making the user wait on a satellite.
      position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 2), onTimeout: () => null)
          .catchError((Object _) => null);
      if (position == null) {
        return const LocationResult(LocationOutcome.timedOut);
      }
    }

    return LocationResult(LocationOutcome.granted, position: position);
  }
}
