import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/config/env.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/core/error/retry_policy.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/core/auth/token_storage.dart';
import 'package:foodloop/core/network/cold_start_interceptor.dart';
import 'package:foodloop/features/auth/data/auth_repository_impl.dart';

/// Times out the first [failures] requests, then answers.
class _ColdAdapter implements HttpClientAdapter {
  _ColdAdapter({this.failures = 1});

  int failures;
  int attempts = 0;
  final budgets = <Duration?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    attempts++;
    budgets.add(options.receiveTimeout);
    if (attempts <= failures) {
      throw DioException.receiveTimeout(
        timeout: options.receiveTimeout ?? Duration.zero,
        requestOptions: options,
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(_ColdAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.invalid',
      receiveTimeout: Env.receiveTimeout,
      connectTimeout: Env.connectTimeout,
    ),
  )..httpClientAdapter = adapter;
  dio.interceptors.add(ColdStartInterceptor(dio));
  return dio;
}

void main() {
  group('the provider retry policy', () {
    test('a refused location is never retried', () {
      // This was the worst bug on the device: the default policy retried it
      // ten times, and each attempt raised the system permission dialog
      // again. Waiting cannot grant a permission.
      expect(foodloopRetry(0, const LocationUnavailable()), isNull);
      expect(foodloopRetry(1, const LocationUnavailable()), isNull);
    });

    test('a considered server answer is never retried', () {
      // Asking nine more times cannot change any of these, and each attempt
      // costs the user a round trip.
      expect(foodloopRetry(0, const UnauthorizedFailure('no')), isNull);
      expect(foodloopRetry(0, const ForbiddenFailure('no')), isNull);
      expect(foodloopRetry(0, const NotFoundFailure('gone')), isNull);
      expect(foodloopRetry(0, const ConflictFailure('taken')), isNull);
      expect(foodloopRetry(0, const ValidationFailure('bad')), isNull);
    });

    test('a programming mistake is not a transient condition', () {
      expect(foodloopRetry(0, StateError('bug')), isNull);
    });

    test('a network blip is retried, but only twice', () {
      expect(foodloopRetry(0, const NetworkFailure()), isNotNull);
      expect(foodloopRetry(1, const NetworkFailure()), isNotNull);
      // Then the screen shows its error and offers a manual retry, which is
      // more honest than a long silent loop.
      expect(foodloopRetry(2, const NetworkFailure()), isNull);
    });

    test('the backoff stays short enough to be worth waiting through', () {
      for (var i = 0; i < 2; i++) {
        expect(
          foodloopRetry(i, const NetworkFailure()),
          lessThanOrEqualTo(const Duration(seconds: 2)),
        );
      }
    });
  });

  _coldStartSignIn();

  group('cold start', () {
    test('a timed-out read is retried once, on a longer budget', () async {
      // Measured: first request after idle 36.0s, second 1.4s, rest 0.94s.
      // The ordinary budget is right for a warm server and hopeless for a
      // cold one, so the retry carries its own.
      final adapter = _ColdAdapter();
      final response = await _client(adapter).get<Map<String, dynamic>>('/x');

      expect(response.statusCode, 200);
      expect(adapter.attempts, 2);
      expect(adapter.budgets.first, Env.receiveTimeout);
      expect(adapter.budgets.last, ColdStartInterceptor.wakeTimeout);
      // Long enough to cover the measured wake.
      expect(
        ColdStartInterceptor.wakeTimeout,
        greaterThan(const Duration(seconds: 36)),
      );
    });

    test('it gives up after one retry rather than looping', () async {
      final adapter = _ColdAdapter(failures: 5);

      await expectLater(
        _client(adapter).get<Map<String, dynamic>>('/x'),
        throwsA(isA<DioException>()),
      );
      // The second failure belongs on screen, where the user can decide
      // whether to wait.
      expect(adapter.attempts, 2);
    });

    test('a write is never replayed', () async {
      // Retrying a claim could hand the same food to one person twice. The
      // rescue endpoints are not idempotent and must never be replayed by
      // machinery the caller cannot see.
      final adapter = _ColdAdapter(failures: 5);

      await expectLater(
        _client(adapter).post<Map<String, dynamic>>('/rescues'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.attempts, 1);
    });

    test('a real error is not mistaken for a cold start', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = _RefusingAdapter();
      dio.interceptors.add(ColdStartInterceptor(dio));

      await expectLater(
        dio.get<Map<String, dynamic>>('/x'),
        throwsA(isA<DioException>()),
      );
    });

    test('the ordinary budget still applies to everything else', () {
      // The retry is not a blanket timeout increase: normal traffic keeps the
      // short budget, which is what stops a broken connection hanging the UI.
      expect(Env.receiveTimeout, lessThanOrEqualTo(const Duration(seconds: 12)));
      expect(coldStartRetryIsNeeded, isTrue);
    });
  });
}

/// Answers with a 500 — an answer, not a timeout.
class _RefusingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{"error":"boom"}', 500);

  @override
  void close({bool force = false}) {}
}

// ------------------------------------------------- signing in on a cold host

/// Accepts tokens and forgets them. Signing in writes a pair; nothing in
/// these tests reads them back.
class _NullTokenStorage implements TokenStorage {
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// Records the budget each request was sent with.
class _BudgetRecorder implements HttpClientAdapter {
  final budgets = <String, Duration?>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    budgets[options.path] = options.receiveTimeout;
    return ResponseBody.fromString(
      '{"access_token":"a","refresh_token":"r","expires_at":"2026-01-01T00:00:00Z",'
      '"user":{"id":"u1","email":"a@b.c","full_name":"A","role":"consumer",'
      '"status":"active","email_verified":true,"is_staff":false,'
      '"created_at":"2026-01-01T00:00:00Z"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void _coldStartSignIn() {
  group('signing in on a cold host', () {
    test('login really is sent with the long budget', () async {
      // Measured: the deployed API sleeps when idle and takes ~27-32s to
      // wake. With the ordinary 10s budget every first sign-in after an idle
      // period timed out, and the cold-start retry could not help because it
      // is GET-only and a login is a POST.
      final adapter = _BudgetRecorder();
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.invalid',
          receiveTimeout: Env.receiveTimeout,
        ),
      )..httpClientAdapter = adapter;

      await AuthRepositoryImpl(dio, _NullTokenStorage()).signIn(
        email: 'a@b.c',
        password: 'irrelevant-to-this-test',
      );

      expect(adapter.budgets['/auth/login'], ColdStartInterceptor.wakeTimeout);
      expect(
        ColdStartInterceptor.wakeTimeout,
        greaterThan(const Duration(seconds: 32)),
        reason: 'must outlast the measured wake',
      );
    });

    test('a login is still never replayed automatically', () async {
      // The longer budget is deliberately *instead of* a retry: replaying a
      // POST is how one tap becomes two sessions.
      final adapter = _ColdAdapter(failures: 5);
      await expectLater(
        _client(adapter).post<Map<String, dynamic>>('/auth/login'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.attempts, 1);
    });
  });
}
