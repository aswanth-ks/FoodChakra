/// Compile-time environment configuration.
///
/// Values are injected with `--dart-define` so no URL or secret is ever
/// hardcoded in source (see the code-quality rules in `docs/ARCHITECTURE.md`).
///
/// Example:
/// ```
/// flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
/// ```
class Env {
  const Env._();

  /// Backend origin, without the `/api/v1` suffix.
  ///
  /// Defaults to the desktop/web loopback address. Android emulators must pass
  /// `http://10.0.2.2:8000`, because `localhost` there refers to the emulator.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String apiVersionPrefix = '/api/v1';

  /// Full API root, e.g. `http://127.0.0.1:8000/api/v1`.
  static String get apiUrl => '$apiBaseUrl$apiVersionPrefix';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Enables verbose network logging. Off in release builds.
  static const bool enableNetworkLogs = bool.fromEnvironment(
    'ENABLE_NETWORK_LOGS',
    defaultValue: true,
  );
}
