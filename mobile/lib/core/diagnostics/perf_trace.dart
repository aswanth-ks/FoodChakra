import 'package:dio/dio.dart';

import '../config/env.dart';

/// Development-only timing trace.
///
/// Off unless the build is made with `--dart-define=PERF_TRACE=true`, so an
/// ordinary release carries no logging at all — the checks below compile to a
/// constant false and the calls fall away.
///
/// It records only a method, a path and a duration. Never headers, never
/// bodies, never query strings: `/listings/nearby?latitude=…` would write the
/// user's coordinates into the device log, which is exactly the kind of thing
/// that should not survive an investigation.
class PerfTrace {
  const PerfTrace._();

  static final Stopwatch _since = Stopwatch()..start();

  /// Milliseconds since the first use of this class, which in practice is the
  /// first frame of the app.
  static int get elapsedMs => _since.elapsedMilliseconds;

  /// `print`, not `dart:developer`: a release build has no VM service
  /// attached, so `developer.log` goes nowhere. stdout reaches logcat.
  // ignore: avoid_print
  static void _emit(String line) => print('FLPERF $line');

  /// Records a named moment in the startup or navigation path.
  static void mark(String label) {
    if (!Env.perfTrace) return;
    _emit('$elapsedMs ms  $label');
  }

  /// Times one span and records it, returning whatever [body] returns.
  static Future<T> span<T>(String label, Future<T> Function() body) async {
    if (!Env.perfTrace) return body();
    final started = elapsedMs;
    try {
      return await body();
    } finally {
      _emit('$elapsedMs ms  $label  (+${elapsedMs - started} ms)');
    }
  }
}

/// Logs how long each request actually took, and nothing about its contents.
///
/// Added last in the interceptor chain so the duration it reports is the whole
/// round trip as the caller experiences it, including the auth interceptor's
/// work.
class PerfTraceInterceptor extends Interceptor {
  final _startedAt = <RequestOptions, int>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _startedAt[options] = PerfTrace.elapsedMs;
    PerfTrace._emit(
      '${PerfTrace.elapsedMs} ms  -> ${options.method} ${options.path}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _finish(response.requestOptions, '${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // The type, not the message: a message can carry a URL with coordinates.
    _finish(err.requestOptions, err.type.name);
    handler.next(err);
  }

  void _finish(RequestOptions options, String outcome) {
    final started = _startedAt.remove(options);
    final took = started == null ? -1 : PerfTrace.elapsedMs - started;
    PerfTrace._emit(
      '${PerfTrace.elapsedMs} ms  <- ${options.method} ${options.path}  '
      '$outcome  ${took}ms',
    );
  }
}
