import 'package:foodloop/core/location/location_service.dart';

/// A location service that answers "cannot say", without a platform channel.
///
/// The real one crosses a method channel that never answers under a test
/// binding, and the bounds added to it then leave their timers pending at
/// teardown — the binding correctly reporting that nothing ever replied.
///
/// [LocationReadiness.unknown] is the deliberate answer: it is what the real
/// service returns when the platform will not say, and the router treats it as
/// "do not block the app", so a test that is not about location is not
/// diverted through location onboarding.
///
/// Test-only. Tests that are about location use their own fakes with
/// controllable outcomes.
class InertLocationService implements LocationService {
  const InertLocationService();

  @override
  Future<LocationReadiness> readiness() async => LocationReadiness.unknown;

  @override
  Future<LocationResult> requestLocation() async =>
      const LocationResult(LocationOutcome.unavailable);

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
