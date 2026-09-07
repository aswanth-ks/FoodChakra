import '../domain/health_status.dart';

/// Wire format for `GET /api/v1/health`.
///
/// DTOs own JSON parsing and convert to a domain entity. Entities never carry
/// `fromJson`, which keeps the domain independent of the API shape.
class HealthDto {
  const HealthDto({
    required this.status,
    required this.app,
    required this.environment,
    required this.databaseConnected,
    this.databaseVersion,
  });

  final String status;
  final String app;
  final String environment;
  final bool databaseConnected;
  final String? databaseVersion;

  factory HealthDto.fromJson(Map<String, dynamic> json) {
    final database = (json['database'] as Map?)?.cast<String, dynamic>() ?? {};
    return HealthDto(
      status: json['status'] as String? ?? 'degraded',
      app: json['app'] as String? ?? 'FoodLoop',
      environment: json['environment'] as String? ?? 'unknown',
      databaseConnected: database['connected'] as bool? ?? false,
      databaseVersion: database['version'] as String?,
    );
  }

  HealthStatus toDomain() => HealthStatus(
    status: status,
    app: app,
    environment: environment,
    databaseConnected: databaseConnected,
    databaseVersion: databaseVersion,
  );
}
