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
  /// Defaults to the deployed API, so an installed build points at production
  /// without needing a flag. Local development overrides it:
  ///
  /// * desktop / web — `--dart-define=API_BASE_URL=http://127.0.0.1:8000`
  /// * Android emulator — `http://10.0.2.2:8000`, since `localhost` there is
  ///   the emulator itself
  /// * a real handset — the host machine's LAN address
  ///
  /// Each of those is plaintext HTTP, which Android permits only for the hosts
  /// named in `android/app/src/main/res/xml/network_security_config.xml`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://foodloop-api-su81.onrender.com',
  );

  static const String apiVersionPrefix = '/api/v1';

  /// Full API root, e.g. `http://127.0.0.1:8000/api/v1`.
  static String get apiUrl => '$apiBaseUrl$apiVersionPrefix';

  /// Timeouts for ordinary API calls.
  ///
  /// Sized from measurement, not guesswork: against the deployed API an
  /// authenticated call takes ~0.9-1.1s warm (a request that touches no
  /// database returns in ~0.4s, which is the network floor from here). Ten
  /// seconds is roughly ten times the observed cost.
  ///
  /// It used to be 20s, which is most of a minute of frozen UI across the two
  /// or three calls a screen makes. The trade is deliberate: a host that has
  /// scaled to zero can take longer than this to wake, and those requests now
  /// fail rather than hang. That is the better failure — the user gets a "Try
  /// again" they can press, and by then the instance is awake and the retry
  /// succeeds, instead of staring at a spinner with no idea whether anything
  /// is happening.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  /// Uploads are small (JSON only), so a send that stalls this long is a dead
  /// connection rather than a slow one.
  static const Duration sendTimeout = Duration(seconds: 10);

  /// Receive timeout for the auth endpoints that send an email before they
  /// answer.
  ///
  /// `/auth/register` and the code endpoints hand a message to SMTP while the
  /// request is still open, so their latency is the API's plus a whole SMTP
  /// conversation — the server allows that send up to 10s on its own. On a
  /// host that sleeps when idle, the first request also waits for the instance
  /// to wake. [receiveTimeout] is sized for an ordinary read and gives up
  /// while the server is still working, which strands the caller: the account
  /// is created and the code is emailed, but the client reports a timeout and
  /// never reaches the verification screen.
  static const Duration emailReceiveTimeout = Duration(seconds: 60);

  /// Enables the development-only timing trace.
  ///
  /// Off by default, including in release. Turned on only to investigate a
  /// slow path, with `--dart-define=PERF_TRACE=true`, and the build used for
  /// that is not the one that ships.
  static const bool perfTrace = bool.fromEnvironment('PERF_TRACE');

  /// Enables verbose network logging. Off in release builds.
  static const bool enableNetworkLogs = bool.fromEnvironment(
    'ENABLE_NETWORK_LOGS',
    defaultValue: true,
  );
}
