import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/network/redacting_log_interceptor.dart';

/// Answers every request with a fixed body, so a full round trip can be logged.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.body, {this.status = 200});

  final String body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<String> lines;

  Dio clientReturning(String body, {int status = 200}) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = StubAdapter(body, status: status)
      ..interceptors.add(RedactingLogInterceptor(log: lines.add));
    return dio;
  }

  setUp(() => lines = []);

  String logged() => lines.join(' | ');

  test('a sign-in password never reaches the log', () async {
    final dio = clientReturning('{"ok":true}');

    await dio.post<dynamic>('/auth/login', data: {
      'email': 'asha@example.com',
      'password': 'a-real-password',
    });

    expect(logged(), contains('/auth/login'));
    // The address is fine — it is not a credential, and it is what makes a
    // log entry useful. The password is not.
    expect(logged(), contains('asha@example.com'));
    expect(logged(), isNot(contains('a-real-password')));
    expect(logged(), contains('***'));
  });

  test('a verification code never reaches the log', () async {
    final dio = clientReturning('{"message":"ok"}');

    await dio.post<dynamic>('/auth/verify-email', data: {
      'email': 'asha@example.com',
      'code': '481920',
    });

    expect(logged(), isNot(contains('481920')));
  });

  test('a new password on reset never reaches the log', () async {
    final dio = clientReturning('{"message":"ok"}');

    await dio.post<dynamic>('/auth/reset-password', data: {
      'email': 'asha@example.com',
      'code': '481920',
      'new_password': 'a-brand-new-password',
    });

    expect(logged(), isNot(contains('481920')));
    expect(logged(), isNot(contains('a-brand-new-password')));
  });

  test('a handover code never reaches the log', () async {
    final dio = clientReturning('{"status":"verified"}');

    await dio.post<dynamic>('/rescues/r1/verify', data: {'code': '112233'});

    expect(logged(), isNot(contains('112233')));
  });

  test('tokens in a login response never reach the log', () async {
    final dio = clientReturning(
      '{"access_token":"header.payload.signature",'
      '"refresh_token":"another.jwt.value",'
      '"user":{"email":"asha@example.com","role":"consumer"}}',
    );

    await dio.post<dynamic>('/auth/login', data: {'email': 'a@b.com'});

    expect(logged(), isNot(contains('header.payload.signature')));
    expect(logged(), isNot(contains('another.jwt.value')));
    // The rest of the response is still legible, which is the point of
    // redacting rather than simply not logging.
    expect(logged(), contains('consumer'));
  });

  test('a nested credential is redacted too', () async {
    final dio = clientReturning(
      '{"session":{"tokens":{"access_token":"deep.jwt.value"}}}',
    );

    await dio.get<dynamic>('/auth/me');

    expect(logged(), isNot(contains('deep.jwt.value')));
  });

  test('an error response is scrubbed as well', () async {
    final dio = clientReturning(
      '{"error":{"code":"UNAUTHORIZED","message":"Invalid email or password."}}',
      status: 401,
    );

    await expectLater(
      dio.post<dynamic>('/auth/login', data: {
        'email': 'asha@example.com',
        'password': 'a-real-password',
      }),
      throwsA(isA<DioException>()),
    );

    expect(logged(), isNot(contains('a-real-password')));
    // The envelope's `code` is redacted along with every other `code`: the
    // interceptor fails closed rather than trying to tell an error code from
    // a one-time code. The message and the status still identify the failure.
    expect(logged(), contains('Invalid email or password.'));
    expect(logged(), contains('401'));
  });

  test('a body it cannot inspect is reported by type, not by content',
      () async {
    final dio = clientReturning('{"ok":true}');

    await dio.post<dynamic>('/listings', data: 'raw-string-body');

    expect(logged(), isNot(contains('raw-string-body')));
    expect(logged(), contains('String'));
  });

  test('the method, path and status are still logged', () async {
    final dio = clientReturning('{"items":[]}');

    await dio.get<dynamic>('/listings/nearby');

    expect(logged(), contains('GET'));
    expect(logged(), contains('/api/v1/listings/nearby'));
    expect(logged(), contains('200'));
  });
}
