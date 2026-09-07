import 'health_status.dart';

/// Repository contract owned by the domain layer.
///
/// The presentation layer depends on this interface, never on the concrete
/// implementation, so data sources can be swapped or faked in tests.
abstract interface class HealthRepository {
  Future<HealthStatus> fetchHealth();
}
