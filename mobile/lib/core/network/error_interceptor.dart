import 'package:dio/dio.dart';

import '../error/failures.dart';

/// Translates transport errors into domain [Failure]s.
///
/// The backend guarantees a single error envelope:
/// `{"error": {"code": ..., "message": ..., "details": {...}}}`
/// so the message shown to a user comes from the server whenever one exists.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: _toFailure(err),
      ),
    );
  }

  Failure _toFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const NetworkFailure();
      case DioExceptionType.cancel:
        return const UnknownFailure('The request was cancelled.');
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Insecure connection.');
      case DioExceptionType.badResponse:
        return _fromResponse(err.response);
    }
  }

  Failure _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final envelope = _envelope(response?.data);
    final message = envelope?['message'] as String?;
    final code = envelope?['code'] as String?;
    final details = envelope?['details'] as Map<String, dynamic>?;

    return switch (status) {
      401 => UnauthorizedFailure(message ?? 'Please sign in again.'),
      // The code, not the status, distinguishes these two: both are 403, but
      // one means "sign in again" and the other means "go and verify".
      403 when code == 'EMAIL_NOT_VERIFIED' => EmailNotVerifiedFailure(
        message ?? 'Verify your email address to sign in.',
      ),
      403 => ForbiddenFailure(
        message ?? 'You do not have permission to do this.',
      ),
      404 => NotFoundFailure(message ?? 'Not found.'),
      422 => ValidationFailure(
        message ?? 'Please check the highlighted fields.',
        code: code,
        details: details,
      ),
      429 => TooManyAttemptsFailure(
        message ?? 'Too many attempts. Please try again in a moment.',
      ),
      503 => ServiceUnavailableFailure(
        message ?? 'That service is unavailable right now.',
      ),
      >= 500 => ServerFailure(
        message ?? 'Something went wrong. Please try again.',
      ),
      _ => UnknownFailure(message ?? 'An unexpected error occurred.'),
    };
  }

  Map<String, dynamic>? _envelope(dynamic data) {
    if (data is Map && data['error'] is Map) {
      return Map<String, dynamic>.from(data['error'] as Map);
    }
    return null;
  }
}
