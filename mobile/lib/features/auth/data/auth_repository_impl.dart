import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../../core/error/failures.dart';
import '../domain/account.dart';
import '../domain/auth_repository.dart';
import 'auth_dto.dart';
import '../../../core/auth/token_storage.dart';

/// Talks to `/api/v1/auth` and returns domain entities.
///
/// `ErrorInterceptor` has already converted transport problems into a
/// [Failure]; this class only unwraps them so callers never handle Dio types.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    // Deliberately sends only these three fields. Role and status are the
    // server's to assign; it rejects the request outright if either is sent.
    //
    // No tokens come back, so nothing is written to storage here. A 503 means
    // the account exists but the code email failed — the screen says so
    // rather than sending the user to wait for mail that never arrives.
    await _post('/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
    });
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _post('/auth/verify-email', {'email': email, 'code': code});
  }

  @override
  Future<void> resendVerification(String email) async {
    await _post('/auth/verify-email/resend', {'email': email});
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post('/auth/reset-password', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  /// Posts and discards the body, surfacing the server's `Failure`.
  ///
  /// These endpoints return an acknowledgement and nothing else — no account,
  /// no tokens, and never a code.
  ///
  /// Every one of them emails a code before it answers, so they are given
  /// `Env.emailReceiveTimeout` rather than the client-wide read timeout. The
  /// default is sized for an ordinary API read and expires while the server is
  /// still talking to SMTP — the work then completes server-side while the
  /// caller sees a timeout, which is how a registered user with the code
  /// already in their inbox ends up stuck on the form.
  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(receiveTimeout: Env.emailReceiveTimeout),
      );
    } on DioException catch (e) {
      throw e.error is Failure ? e.error as Failure : const UnknownFailure();
    }
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    return _authenticate('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  @override
  Future<Account?> restoreSession() async {
    final token = await _storage.readAccessToken();
    if (token == null) return null;

    try {
      // The interceptor attaches the bearer token; this only checks there is
      // a session worth asking about.
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data;
      if (data == null) return null;
      return AccountDto.fromJson(data).toDomain();
    } on DioException catch (e) {
      final failure = e.error;
      // A rejected or suspended session is not an error the caller needs to
      // handle — it just means "signed out". Clearing the stale tokens stops
      // every later request retrying with credentials the server refuses.
      if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
        await _storage.clear();
        return null;
      }
      // A network problem is different: the tokens may still be perfectly
      // good, so they are kept and the caller decides what to show.
      throw failure is Failure ? failure : const UnknownFailure();
    }
  }

  @override
  Future<void> signOut() async {
    final accessToken = await _storage.readAccessToken();
    final refreshToken = await _storage.readRefreshToken();

    // Local tokens are cleared regardless of what the server says. A failed
    // logout call must never leave the user stuck signed in on the device.
    try {
      if (accessToken != null) {
        await _dio.post<void>(
          '/auth/logout',
          data: refreshToken == null ? null : {'refresh_token': refreshToken},
        );
      }
    } on DioException {
      // Best effort; the session still expires server-side on its own.
    } finally {
      await _storage.clear();
    }
  }

  Future<Account> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = response.data;
      if (data == null) {
        throw const ServerFailure('The server returned an empty response.');
      }
      final tokens = TokenPairDto.fromJson(data);
      await _storage.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return tokens.user.toDomain();
    } on DioException catch (e) {
      throw e.error is Failure ? e.error as Failure : const UnknownFailure();
    }
  }
}
