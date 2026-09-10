import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// Attaches the bearer token to every request, and refreshes it once on a 401.
///
/// Without this, only the two endpoints that set the header by hand were
/// authenticated — every listings and rescues call went out anonymous and the
/// backend refused it. Doing it in one interceptor rather than per repository
/// means a new feature is authenticated by default rather than by remembering.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  /// The client this interceptor is installed on.
  ///
  /// Refresh and replay go back through it rather than through a throwaway
  /// `Dio`, so they inherit the same base URL, timeouts and adapter. Recursion
  /// is not a risk: `/auth/refresh` is a public path, so it is never given a
  /// token and never triggers another refresh, and a replayed request carries
  /// a flag that stops it being retried twice.
  late final Dio _client;

  /// Called once, immediately after construction, by `dioProvider`.
  void attach(Dio client) => _client = client;

  /// Endpoints that must not carry a stale access token, and must never
  /// trigger a refresh: they are how a session is obtained in the first place.
  static const _publicPaths = {
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
  };

  /// Marks a request that has already been retried, so a refresh loop cannot
  /// bounce a single call forever.
  static const _retriedFlag = 'auth_retried';

  static bool _isPublic(String path) =>
      _publicPaths.any((public) => path.endsWith(public));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isRetryable =
        err.response?.statusCode == 401 &&
        !_isPublic(request.path) &&
        request.extra[_retriedFlag] != true;

    if (!isRetryable) {
      handler.next(err);
      return;
    }

    final refreshed = await _refresh();
    if (refreshed == null) {
      // The session is genuinely over. The stored tokens are cleared so every
      // later request fails fast as anonymous rather than retrying credentials
      // the server has already rejected.
      await _storage.clear();
      handler.next(err);
      return;
    }

    try {
      request.extra[_retriedFlag] = true;
      request.headers['Authorization'] = 'Bearer $refreshed';
      final response = await _client.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Exchanges the refresh token for a new pair. Returns the new access token,
  /// or null when the session cannot be renewed.
  Future<String?> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final access = data?['access_token'] as String?;
      final refresh = data?['refresh_token'] as String?;
      if (access == null || refresh == null) return null;

      // Rotation is single-use server-side, so the new pair must replace the
      // old one immediately or the next refresh is treated as a replay.
      await _storage.save(accessToken: access, refreshToken: refresh);
      return access;
    } on DioException {
      return null;
    }
  }
}
