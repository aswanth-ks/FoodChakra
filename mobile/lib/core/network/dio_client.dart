import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';
import 'auth_interceptor.dart';
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
      headers: {'Content-Type': 'application/json'},
      // Let the error interceptor classify every non-2xx response.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  // Order matters: the auth interceptor must see a raw 401 before the error
  // interceptor converts it into a Failure and rejects the chain.
  final auth = AuthInterceptor(ref.watch(tokenStorageProvider))..attach(dio);
  dio.interceptors.add(auth);
  dio.interceptors.add(ErrorInterceptor());

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
