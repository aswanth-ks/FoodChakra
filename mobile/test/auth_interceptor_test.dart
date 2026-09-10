import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/auth/token_storage.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/core/network/auth_interceptor.dart';
import 'package:foodloop/core/network/error_interceptor.dart';
import 'package:foodloop/features/auth/data/auth_repository_impl.dart';

/// In-memory secure storage, so these run without a platform channel.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers requests without a network, recording what it was sent.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeSecureStorage secure;
  late TokenStorage storage;

  setUp(() {
    secure = FakeSecureStorage();
    storage = TokenStorage(secure);
  });

  Dio clientThatAnswers(ResponseBody Function(RequestOptions) respond) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    dio.httpClientAdapter = RecordingAdapter(respond);
    dio.interceptors.add(AuthInterceptor(storage)..attach(dio));
    return dio;
  }

  ResponseBody ok(Map<String, dynamic> body) =>
      ResponseBody.fromString(_json(body), 200, headers: _jsonHeaders);

  test('attaches the stored bearer token to an ordinary request', () async {
    await storage.save(accessToken: 'access-1', refreshToken: 'refresh-1');
    final adapter = RecordingAdapter((_) => ok({'items': []}));
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(storage));
    dio.interceptors.whereType<AuthInterceptor>().single.attach(dio);

    await dio.get<dynamic>('/listings/nearby');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer access-1',
    );
  });

  test('sends no token when signed out', () async {
    final adapter = RecordingAdapter((_) => ok({'items': []}));
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(storage));
    dio.interceptors.whereType<AuthInterceptor>().single.attach(dio);

    await dio.get<dynamic>('/listings/nearby');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('never attaches a token to login or register', () async {
    await storage.save(accessToken: 'access-1', refreshToken: 'refresh-1');
    final adapter = RecordingAdapter((_) => ok({'access_token': 'x'}));
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(storage));
    dio.interceptors.whereType<AuthInterceptor>().single.attach(dio);

    await dio.post<dynamic>('/auth/login', data: {});
    await dio.post<dynamic>('/auth/register', data: {});

    for (final request in adapter.requests) {
      expect(request.headers.containsKey('Authorization'), isFalse);
    }
  });

  test('a 401 refreshes once and replays the request', () async {
    await storage.save(accessToken: 'stale', refreshToken: 'refresh-1');
    var listingCalls = 0;

    final dio = clientThatAnswers((options) {
      if (options.path.endsWith('/auth/refresh')) {
        return ok({
          'access_token': 'fresh',
          'refresh_token': 'refresh-2',
        });
      }
      listingCalls++;
      // The first attempt carries the stale token and is refused; the replay
      // carries the fresh one.
      if (options.headers['Authorization'] == 'Bearer fresh') {
        return ok({'items': []});
      }
      return ResponseBody.fromString('{}', 401, headers: _jsonHeaders);
    });

    final response = await dio.get<dynamic>('/listings/nearby');

    expect(response.statusCode, 200);
    expect(listingCalls, 2, reason: 'original attempt plus one replay');
    // The rotated pair replaced the old one — the server treats a reused
    // refresh token as a replay.
    expect(await storage.readAccessToken(), 'fresh');
    expect(await storage.readRefreshToken(), 'refresh-2');
  });

  test('a failed refresh clears the session instead of looping', () async {
    await storage.save(accessToken: 'stale', refreshToken: 'expired');
    var listingCalls = 0;

    final dio = clientThatAnswers((options) {
      if (options.path.endsWith('/auth/refresh')) {
        return ResponseBody.fromString('{}', 401, headers: _jsonHeaders);
      }
      listingCalls++;
      return ResponseBody.fromString('{}', 401, headers: _jsonHeaders);
    });

    await expectLater(
      dio.get<dynamic>('/listings/nearby'),
      throwsA(isA<DioException>()),
    );

    expect(listingCalls, 1, reason: 'no replay when the refresh failed');
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('a persistent 401 is not retried forever', () async {
    await storage.save(accessToken: 'stale', refreshToken: 'refresh-1');
    var listingCalls = 0;

    final dio = clientThatAnswers((options) {
      if (options.path.endsWith('/auth/refresh')) {
        return ok({'access_token': 'fresh', 'refresh_token': 'refresh-2'});
      }
      listingCalls++;
      return ResponseBody.fromString('{}', 401, headers: _jsonHeaders);
    });

    await expectLater(
      dio.get<dynamic>('/listings/nearby'),
      throwsA(isA<DioException>()),
    );

    // One original call and exactly one replay, then it gives up.
    expect(listingCalls, 2);
  });

  test('a 403 is not treated as an expired session', () async {
    await storage.save(accessToken: 'access-1', refreshToken: 'refresh-1');
    var refreshCalls = 0;

    final dio = clientThatAnswers((options) {
      if (options.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        return ok({'access_token': 'fresh', 'refresh_token': 'r2'});
      }
      return ResponseBody.fromString('{}', 403, headers: _jsonHeaders);
    });

    await expectLater(
      dio.post<dynamic>('/rescues/r1/verify', data: {'code': '000000'}),
      throwsA(isA<DioException>()),
    );

    // A suspended account or a forbidden action is not fixed by a new token.
    expect(refreshCalls, 0);
    expect(await storage.readAccessToken(), 'access-1');
  });

  // Startup session restoration, end to end over the same interceptor stack
  // the app installs. There is deliberately no second refresh mechanism: the
  // restore is an ordinary `/auth/me` call, and the interceptor does the rest.
  group('session restoration', () {
    Dio stack(ResponseBody Function(RequestOptions) respond) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = RecordingAdapter(respond);
      dio.interceptors.add(AuthInterceptor(storage)..attach(dio));
      dio.interceptors.add(ErrorInterceptor());
      return dio;
    }

    ResponseBody account() => ResponseBody.fromString(
      jsonEncode({
        'id': 'u1',
        'email': 'asha@example.com',
        'full_name': 'Asha Rao',
        'role': 'consumer',
        'status': 'active',
        'email_verified': true,
        'is_staff': false,
      }),
      200,
      headers: _jsonHeaders,
    );

    test('no stored token restores nothing without calling the API', () async {
      var calls = 0;
      final dio = stack((_) {
        calls++;
        return account();
      });

      expect(await AuthRepositoryImpl(dio, storage).restoreSession(), isNull);
      expect(calls, 0);
    });

    test('a valid access token restores the session', () async {
      await storage.save(accessToken: 'good', refreshToken: 'refresh-1');
      final dio = stack((_) => account());

      final restored = await AuthRepositoryImpl(dio, storage).restoreSession();

      expect(restored?.email, 'asha@example.com');
      expect(restored?.role.isPartner, isFalse);
    });

    test('an expired access token is refreshed and the restore succeeds',
        () async {
      await storage.save(accessToken: 'stale', refreshToken: 'refresh-1');
      var meCalls = 0;

      final dio = stack((options) {
        if (options.path.endsWith('/auth/refresh')) {
          return ok({'access_token': 'fresh', 'refresh_token': 'refresh-2'});
        }
        meCalls++;
        if (options.headers['Authorization'] == 'Bearer fresh') {
          return account();
        }
        return ResponseBody.fromString('{}', 401, headers: _jsonHeaders);
      });

      final restored = await AuthRepositoryImpl(dio, storage).restoreSession();

      expect(restored?.id, 'u1');
      expect(meCalls, 2, reason: 'refused once, then replayed');
      expect(await storage.readAccessToken(), 'fresh');
    });

    test('a failed refresh clears the session and restores nothing', () async {
      await storage.save(accessToken: 'stale', refreshToken: 'expired');

      final dio = stack(
        (_) => ResponseBody.fromString('{}', 401, headers: _jsonHeaders),
      );

      expect(await AuthRepositoryImpl(dio, storage).restoreSession(), isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });

    test('a suspended account clears the session without a refresh', () async {
      await storage.save(accessToken: 'good', refreshToken: 'refresh-1');
      var refreshCalls = 0;

      final dio = stack((options) {
        if (options.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return ok({'access_token': 'fresh', 'refresh_token': 'r2'});
        }
        // What the backend answers for a non-active account: a new token
        // would not help, so the session is over.
        return ResponseBody.fromString('{}', 403, headers: _jsonHeaders);
      });

      expect(await AuthRepositoryImpl(dio, storage).restoreSession(), isNull);
      expect(refreshCalls, 0);
      expect(await storage.readAccessToken(), isNull);
    });

    test('a network outage keeps the tokens rather than signing the user out',
        () async {
      await storage.save(accessToken: 'good', refreshToken: 'refresh-1');

      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = _FailingAdapter();
      dio.interceptors.add(AuthInterceptor(storage)..attach(dio));
      dio.interceptors.add(ErrorInterceptor());

      await expectLater(
        AuthRepositoryImpl(dio, storage).restoreSession(),
        throwsA(isA<Failure>()),
      );
      // The tokens may be perfectly good; only the network was missing.
      expect(await storage.readAccessToken(), 'good');
    });
  });
}

/// Fails the way an offline device does, rather than with an HTTP status.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  );

  @override
  void close({bool force = false}) {}
}

const _jsonHeaders = {
  Headers.contentTypeHeader: ['application/json'],
};

String _json(Map<String, dynamic> body) {
  final entries = body.entries.map((e) {
    final value = e.value;
    if (value is String) return '"${e.key}":"$value"';
    if (value is List) return '"${e.key}":[]';
    return '"${e.key}":$value';
  });
  return '{${entries.join(',')}}';
}
