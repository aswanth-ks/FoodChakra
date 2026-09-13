import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// What came of an attempt to renew the session.
sealed class _RefreshOutcome {
  const _RefreshOutcome();
}

/// The server issued a new pair, already saved.
class _Renewed extends _RefreshOutcome {
  const _Renewed(this.accessToken);

  final String accessToken;
}

/// The server was reached and said no. The session is genuinely over.
class _Refused extends _RefreshOutcome {
  const _Refused();
}

/// The server could not be reached, so nothing is known about the session.
///
/// Deliberately distinct from [_Refused]. A dropped connection, a timeout or a
/// backend still waking up is not evidence that the credentials are bad, and
/// throwing them away would sign out anyone who walked into a lift.
class _Unreachable extends _RefreshOutcome {
  const _Unreachable();
}

/// Attaches the bearer token to every request, and renews it on a 401.
///
/// Without this, only the two endpoints that set the header by hand were
/// authenticated — every listings and rescues call went out anonymous and the
/// backend refused it. Doing it in one interceptor rather than per repository
/// means a new feature is authenticated by default rather than by remembering.
///
/// Renewal is **single-flight**. The backend rotates refresh tokens on use and
/// treats a second presentation of a spent one as a replay — evidence of
/// theft — by revoking every session on the account. So when several requests
/// expire together, which is the normal shape of a screen load, they must
/// share one renewal rather than each starting their own. They did not, and
/// the result was an app that destroyed its own session and looked to the
/// server exactly like an attacker.
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

  /// The renewal currently in progress, shared by everyone waiting on it.
  Future<_RefreshOutcome>? _inFlight;

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

    // Only a 401 means "your token is no good". A 403, 404, 409 or 5xx is a
    // considered answer about something else, and renewing the session would
    // neither change it nor be honest about what went wrong.
    final isRetryable =
        err.response?.statusCode == 401 &&
        !_isPublic(request.path) &&
        request.extra[_retriedFlag] != true;

    if (!isRetryable) {
      handler.next(err);
      return;
    }

    // Someone else may already have renewed while this request was in flight.
    // If the stored token has moved on, this request simply used an old one
    // and can be replayed as-is — no second renewal, and no risk of presenting
    // a refresh token the first renewal already spent.
    final sentWith = request.headers['Authorization'];
    final current = await _storage.readAccessToken();
    if (current != null && sentWith != 'Bearer $current') {
      await _replay(request, current, handler, err);
      return;
    }

    final outcome = await _renew();
    switch (outcome) {
      case _Renewed(:final accessToken):
        await _replay(request, accessToken, handler, err);
      case _Refused():
        // The server was asked and said no. Clearing the stored tokens stops
        // every later request retrying credentials it has already rejected.
        await _storage.clear();
        handler.next(err);
      case _Unreachable():
        // Nothing was learned. The credentials stay exactly where they are,
        // and the caller sees a network failure — which is what happened.
        handler.next(err);
    }
  }

  Future<void> _replay(
    RequestOptions request,
    String accessToken,
    ErrorInterceptorHandler handler,
    DioException original,
  ) async {
    try {
      request.extra[_retriedFlag] = true;
      request.headers['Authorization'] = 'Bearer $accessToken';
      handler.resolve(await _client.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Renews the session, or joins the renewal already running.
  ///
  /// The single-flight guard is the whole point: concurrent callers must not
  /// each present the same refresh token, because the second presentation is
  /// a replay and costs the account every one of its sessions.
  Future<_RefreshOutcome> _renew() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final started = _refresh();
    _inFlight = started;
    // Cleared only if this is still the current attempt, so a renewal that
    // started later is never cancelled by an earlier one finishing.
    unawaited(
      started.whenComplete(() {
        if (identical(_inFlight, started)) _inFlight = null;
      }),
    );
    return started;
  }

  /// Exchanges the refresh token for a new pair.
  Future<_RefreshOutcome> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    // Nothing to renew with. That is an answer, not a network problem.
    if (refreshToken == null) return const _Refused();

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final access = data?['access_token'] as String?;
      final refresh = data?['refresh_token'] as String?;
      if (access == null || refresh == null) return const _Refused();

      // Rotation is single-use server-side, so the new pair must replace the
      // old one immediately or the next refresh is treated as a replay.
      await _storage.save(accessToken: access, refreshToken: refresh);
      return _Renewed(access);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // A reply from the server refusing the token ends the session. Anything
      // else — a timeout, a dropped connection, a backend still waking up —
      // leaves the session untouched, because none of it is evidence.
      if (status == 401 || status == 403) return const _Refused();
      return const _Unreachable();
    }
  }
}
