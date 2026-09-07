/// Domain entity. Pure Dart — no JSON, no Dio, no Flutter.
class HealthStatus {
  const HealthStatus({
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

  bool get isHealthy => status == 'ok' && databaseConnected;
}
