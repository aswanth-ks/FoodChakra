import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/auth/token_storage.dart';
import 'package:foodloop/core/network/auth_interceptor.dart';

/// An in-memory token store that counts its writes and clears.
///
/// Test-only. Production uses the platform's encrypted storage, whose channel
/// never answers under a test binding.
class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.access, this.refresh});

  String? access;
  String? refresh;
  int clears = 0;
  int saves = 0;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    saves++;
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    clears++;
    access = null;
    refresh = null;
  }
}

/// Stands in for the backend's single-use refresh rotation.
///
/// The real service consumes the refresh token's `jti` atomically. Presenting
/// a consumed one is treated as a replay — evidence the token was captured —
/// so it revokes **every** session for the account rather than just refusing
/// the request. That is the behaviour this fake reproduces, because it is what
/// turns a client-side refresh race into a destroyed session.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend({required this.validAccess, required this.validRefresh});

  String validAccess;
  String validRefresh;

  /// Refresh tokens already spent. Presenting one again is a replay.
  final consumedRefreshTokens = <String>{};

  int refreshCalls = 0;
  bool allSessionsRevoked = false;
  final protectedCalls = <String>[];

  /// Lets a test hold every refresh until it chooses, so several can be in
  /// flight at once — the race this file exists to pin down.
  Completer<void>? gate;

  int _issued = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      if (gate != null) await gate!.future;

      // Dio hands the adapter whatever the caller passed; a Map is only
      // serialised further down. Accept both shapes.
      final raw = options.data;
      final body = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : (raw! as Map).cast<String, dynamic>();
      final presented = body['refresh_token'] as String;

      if (allSessionsRevoked ||
          consumedRefreshTokens.contains(presented) ||
          presented != validRefresh) {
        // Replay: the server assumes theft and revokes everything.
        if (consumedRefreshTokens.contains(presented)) {
          allSessionsRevoked = true;
        }
        return _json({'error': 'Invalid or expired session.'}, 401);
      }

      consumedRefreshTokens.add(presented);
      _issued++;
      validAccess = 'access-$_issued';
      validRefresh = 'refresh-$_issued';
      return _json({
        'access_token': validAccess,
        'refresh_token': validRefresh,
      }, 200);
    }

    // Any other path is protected.
    protectedCalls.add(options.path);
    final header = options.headers['Authorization'] as String?;
    if (allSessionsRevoked || header != 'Bearer $validAccess') {
      return _json({'error': 'Not authenticated.'}, 401);
    }
    return _json({'ok': true}, 200);
  }

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Never answers — a device with no usable connection.
class _DeadNetwork implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'no route to host',
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(HttpClientAdapter adapter, TokenStorage storage) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = adapter;
  final auth = AuthInterceptor(storage)..attach(dio);
  dio.interceptors.add(auth);
  return dio;
}

void main() {
  group('a single expired request', () {
    test('refreshes once and replays the original request', () async {
      final storage = _MemoryTokenStorage(
        access: 'stale',
        refresh: 'refresh-0',
      );
      final backend = _FakeBackend(
        validAccess: 'current',
        validRefresh: 'refresh-0',
      );
      final dio = _client(backend, storage);

      final response = await dio.get<Map<String, dynamic>>('/auth/me');

      expect(response.statusCode, 200);
      expect(backend.refreshCalls, 1);
      // The replay carried the new token, not the stale one.
      expect(backend.protectedCalls.length, 2);
      expect(storage.access, isNotNull);
      expect(storage.clears, 0, reason: 'the session survived');
    });

    test('a rotated refresh token is persisted', () async {
      final storage = _MemoryTokenStorage(
        access: 'stale',
        refresh: 'refresh-0',
      );
      final backend = _FakeBackend(
        validAccess: 'current',
        validRefresh: 'refresh-0',
      );

      await _client(backend, storage).get<Map<String, dynamic>>('/auth/me');

      // Rotation is single-use server-side: keeping the old one would make the
      // next refresh look like a replay.
      expect(storage.refresh, isNot('refresh-0'));
      expect(storage.saves, 1);
    });
  });

  group('concurrent expiry — the reported sign-out', () {
    test('three simultaneous 401s produce exactly one refresh', () async {
      // This is the shape of a real cold start: Home fires /rescues/mine,
      // /listings/mine and /listings/nearby within about three milliseconds
      // of each other. If the access token has expired, all three come back
      // 401 together.
      final storage = _MemoryTokenStorage(
        access: 'stale',
        refresh: 'refresh-0',
      );
      final backend = _FakeBackend(
        validAccess: 'current',
        validRefresh: 'refresh-0',
      )..gate = Completer<void>();
      final dio = _client(backend, storage);

      final calls = Future.wait([
        dio.get<Map<String, dynamic>>('/rescues/mine'),
        dio.get<Map<String, dynamic>>('/listings/mine'),
        dio.get<Map<String, dynamic>>('/listings/nearby'),
      ]);

      // Let all three reach the refresh before any of them completes.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      backend.gate!.complete();

      final responses = await calls;

      // One refresh, not three. Three would mean two of them presenting a
      // token the first had already consumed.
      expect(backend.refreshCalls, 1);
      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(backend.allSessionsRevoked, isFalse);
      expect(storage.clears, 0);
      expect(storage.access, isNotNull, reason: 'still signed in');
    });

    test('a refresh race does not look like token theft to the server', () async {
      final storage = _MemoryTokenStorage(
        access: 'stale',
        refresh: 'refresh-0',
      );
      final backend = _FakeBackend(
        validAccess: 'current',
        validRefresh: 'refresh-0',
      )..gate = Completer<void>();
      final dio = _client(backend, storage);

      final calls = Future.wait([
        dio.get<Map<String, dynamic>>('/a'),
        dio.get<Map<String, dynamic>>('/b'),
        dio.get<Map<String, dynamic>>('/c'),
        dio.get<Map<String, dynamic>>('/d'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      backend.gate!.complete();
      await calls;

      // Presenting a consumed refresh token makes the backend revoke every
      // session for the account — the app destroys its own session and looks
      // exactly like an attacker replaying a stolen token.
      expect(
        backend.allSessionsRevoked,
        isFalse,
        reason: 'the client must never replay a spent refresh token',
      );
      expect(backend.consumedRefreshTokens.length, 1);
    });
  });

  group('what must not end a session', () {
    test('a network failure keeps the credentials', () async {
      final storage = _MemoryTokenStorage(
        access: 'good',
        refresh: 'refresh-0',
      );
      final network = _DeadNetwork();

      await expectLater(
        _client(network, storage).get<Map<String, dynamic>>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      // No internet is not proof that the session is invalid. Clearing here
      // would sign out every user who walked into a lift.
      expect(storage.clears, 0);
      expect(storage.access, 'good');
      expect(storage.refresh, 'refresh-0');
    });

    test('a refresh that fails on the network keeps the credentials', () async {
      final storage = _MemoryTokenStorage(
        access: 'stale',
        refresh: 'refresh-0',
      );
      final backend = _UnreachableAfter401();

      await expectLater(
        _client(backend, storage).get<Map<String, dynamic>>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      // The 401 was authoritative, but the refresh never reached the server,
      // so nothing is known about whether the session is still good.
      expect(storage.clears, 0);
      expect(storage.refresh, 'refresh-0');
    });

    for (final status in [403, 404, 409, 422, 500]) {
      test('a $status never triggers a refresh', () async {
        final storage = _MemoryTokenStorage(
          access: 'good',
          refresh: 'refresh-0',
        );
        final backend = _FixedStatus(status);

        await expectLater(
          _client(backend, storage).get<Map<String, dynamic>>('/anything'),
          throwsA(isA<DioException>()),
        );

        expect(backend.refreshCalls, 0);
        expect(storage.clears, 0);
      });
    }
  });

  group('what must end a session', () {
    test('a refresh the server authoritatively refuses clears the tokens', () async {
      final storage = _MemoryTokenStorage(
        access: 'stale',
        refresh: 'expired',
      );
      final backend = _FakeBackend(
        validAccess: 'current',
        // The stored refresh token is not the valid one, so the server
        // refuses it outright.
        validRefresh: 'something-else',
      );

      await expectLater(
        _client(backend, storage).get<Map<String, dynamic>>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(storage.clears, 1);
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
    });

    test('no refresh token at all clears the session', () async {
      final storage = _MemoryTokenStorage(access: 'stale');
      final backend = _FakeBackend(
        validAccess: 'current',
        validRefresh: 'refresh-0',
      );

      await expectLater(
        _client(backend, storage).get<Map<String, dynamic>>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(storage.clears, 1);
    });
  });
}

/// 401s the protected call, then cannot be reached for the refresh.
class _UnreachableAfter401 implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route to host',
      );
    }
    return ResponseBody.fromString('{"error":"expired"}', 401);
  }

  @override
  void close({bool force = false}) {}
}

/// Always answers with one status, and counts refresh attempts.
class _FixedStatus implements HttpClientAdapter {
  _FixedStatus(this.status);

  final int status;
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) refreshCalls++;
    return ResponseBody.fromString('{"error":"no"}', status);
  }

  @override
  void close({bool force = false}) {}
}
