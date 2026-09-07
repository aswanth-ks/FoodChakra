import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'error_interceptor.dart';

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
      headers: {'Content-Type': 'application/json'},
      // Let the error interceptor classify every non-2xx response.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.add(ErrorInterceptor());

  if (Env.enableNetworkLogs && kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (Object o) => debugPrint(o.toString()),
      ),
    );
  }

  // Phase 3 adds an AuthInterceptor here to attach the bearer token and
  // transparently refresh it on 401.

  return dio;
});
