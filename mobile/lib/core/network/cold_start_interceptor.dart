import 'package:dio/dio.dart';

import '../config/env.dart';

/// Gives a sleeping backend one chance to wake up.
///
/// Measured against the deployment: the first request after a period of
/// inactivity took **36.0s**, the second 1.4s, and every one after that 0.94s.
/// The host scales to zero and the first caller pays for the instance to start.
///
/// That is a real, measured 36 seconds, and no client setting can make it
/// shorter. What the client controls is what the user sees while it happens.
/// The ordinary 10s budget — right for a warm server, where calls cost about a
/// second — turns every first launch after idle into a failure, and with a
/// retrying provider layer into several.
///
/// So: one retry, once, on a timeout, for reads only, with a budget long
/// enough to cover a cold start. It is not a blanket timeout increase — the
/// normal budget is untouched and still applies to every subsequent request,
/// which is what keeps a genuinely broken connection from hanging the UI.
///
/// Scoped deliberately:
///
/// * **GET only.** Retrying a POST could claim a listing twice. The rescue
///   endpoints are not idempotent and must never be replayed by machinery the
///   caller cannot see.
/// * **Timeouts only.** A 4xx or 5xx is an answer; asking again is pointless.
/// * **Once.** A second failure is a real problem and belongs on screen, where
///   the user can decide whether to wait.
class ColdStartInterceptor extends Interceptor {
  /// Long enough to cover the measured 36s wake, with room to spare. Applies
  /// to the single retry attempt, never to ordinary traffic.
  static const Duration wakeTimeout = Duration(seconds: 45);

  static const String _retriedFlag = 'foodloop.cold_start_retry';

  ColdStartInterceptor(this._dio);

  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    final isTimeout =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout;

    final alreadyRetried = options.extra[_retriedFlag] == true;
    final isRead = options.method.toUpperCase() == 'GET';

    if (!isTimeout || alreadyRetried || !isRead) {
      return handler.next(err);
    }

    try {
      final response = await _dio.fetch<dynamic>(
        options
          ..extra[_retriedFlag] = true
          ..connectTimeout = wakeTimeout
          ..receiveTimeout = wakeTimeout,
      );
      return handler.resolve(response);
    } on DioException catch (retryError) {
      // The second failure is the one the user hears about.
      return handler.next(retryError);
    }
  }
}

/// True when the client's ordinary budget is short enough that a cold start
/// needs the retry above. Kept as a named check so the relationship between
/// the two numbers is stated somewhere rather than implied.
bool get coldStartRetryIsNeeded =>
    Env.receiveTimeout < ColdStartInterceptor.wakeTimeout;
