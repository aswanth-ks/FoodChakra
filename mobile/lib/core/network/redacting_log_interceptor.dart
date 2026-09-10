import 'package:dio/dio.dart';

/// Network logging that cannot leak a credential.
///
/// Dio's own `LogInterceptor(requestBody: true, responseBody: true)` prints
/// every header and every body verbatim. On the FoodLoop endpoints that means
/// the device log ends up holding the user's **password** (`/auth/login`),
/// their **one-time code** (`/auth/verify-email`, `/auth/reset-password`),
/// the **handover code** (`/rescues/{id}/verify`), the `Authorization` header,
/// and both tokens from the login response.
///
/// Debug-only is not an answer on its own: an Android debug log is readable
/// over adb and, on older API levels, by other apps on the device — and a
/// developer reading a bug report should not be handed someone's password
/// either.
///
/// So this keeps what logging is actually for — which call, to where, what
/// came back, how long it took — and replaces the value of any field that
/// could be a credential with `***`. The key names stay, so the shape of the
/// payload is still legible.
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor({this.log = print});

  /// Where a line goes. Injectable so tests can capture it.
  final void Function(String line) log;

  /// Fields whose *values* must never be written to a log.
  ///
  /// Matched case-insensitively against the whole key, so `new_password` and
  /// `handover_code` are covered by their own entries rather than by a
  /// substring rule that might miss a future field.
  ///
  /// `code` is the awkward one: in a request it is a one-time code, but in the
  /// server's error envelope it is `UNAUTHORIZED`. This redacts both. Failing
  /// closed costs a little debugging convenience — the envelope's `message`
  /// and the HTTP status both survive — whereas failing open would put a live
  /// verification code in the log the first time someone mistyped one.
  static const _redactedKeys = {
    'password',
    'new_password',
    'current_password',
    'code',
    'otp',
    'handover_code',
    'token',
    'access_token',
    'refresh_token',
    'authorization',
    'password_hash',
    'code_hash',
  };

  static const _redacted = '***';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    log('→ ${options.method} ${options.uri.path} ${_scrub(options.data)}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    log(
      '← ${response.statusCode} ${request.method} ${request.uri.path} '
      '${_scrub(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    // The error body carries the server's message, which is written to be
    // safe to show a user — but it goes through the same scrub anyway, since
    // "safe today" is not a property that maintains itself.
    log(
      '✗ ${err.response?.statusCode ?? err.type.name} '
      '${request.method} ${request.uri.path} ${_scrub(err.response?.data)}',
    );
    handler.next(err);
  }

  /// Replaces every sensitive value in a decoded body, at any depth.
  ///
  /// A body that is not a map — a string, a stream, form data — is reported by
  /// type only. Guessing at its structure well enough to redact it is not
  /// something this can do safely, so it does not try.
  static String _scrub(dynamic data) {
    if (data == null) return '';
    if (data is Map) return _scrubMap(data).toString();
    if (data is List) return data.map<dynamic>(_scrubValue).toList().toString();
    return '<${data.runtimeType}>';
  }

  static Map<String, dynamic> _scrubMap(Map<dynamic, dynamic> source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _redactedKeys.contains(
              entry.key.toString().toLowerCase(),
            )
            ? _redacted
            : _scrubValue(entry.value),
    };
  }

  static dynamic _scrubValue(dynamic value) {
    if (value is Map) return _scrubMap(value);
    if (value is List) return value.map<dynamic>(_scrubValue).toList();
    return value;
  }
}
