import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';
import '../diagnostics/perf_trace.dart';
import 'auth_interceptor.dart';
import 'cold_start_interceptor.dart';
import 'error_interceptor.dart';
import 'redacting_log_interceptor.dart';

/// The single HTTP client for the whole app.
///
/// Every remote data source depends on this provider. Nothing constructs its
/// own `Dio` instance, so timeouts, base URL, auth headers, and error mapping
/// are configured in exactly one place.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
      sendTimeout: Env.sendTimeout,
      headers: {'Content-Type': 'application/json'},
      // Let the error interceptor classify every non-2xx response.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  // Order matters: the auth interceptor must see a raw 401 before the error
  // interceptor converts it into a Failure and rejects the chain.
  final auth = AuthInterceptor(ref.watch(tokenStorageProvider))..attach(dio);
  dio.interceptors.add(auth);
  // Before the error interceptor, so a cold-start timeout is retried while it
  // is still a DioException rather than after it has become a Failure the
  // screens would already be showing.
  dio.interceptors.add(ColdStartInterceptor(dio));
  dio.interceptors.add(ErrorInterceptor());

  // Last in the chain, so the duration it reports is the whole round trip as
  // the caller experiences it. Compiled out unless PERF_TRACE was defined.
  if (Env.perfTrace) dio.interceptors.add(PerfTraceInterceptor());

  if (Env.enableNetworkLogs && kDebugMode) {
    // Not Dio's `LogInterceptor`: with `requestBody`/`responseBody` on it
    // writes passwords, one-time codes, handover codes and both tokens
    // straight into the device log. This one redacts them.
    dio.interceptors.add(
      RedactingLogInterceptor(log: debugPrint),
    );
  }

  return dio;
});
