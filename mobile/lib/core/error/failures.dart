/// Domain-level failures.
///
/// The UI never sees a `DioException`. The network layer converts every
/// transport error into one of these, so widgets can switch on a stable type
/// and show the right message.
sealed class Failure implements Exception {
  const Failure(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// No connectivity, DNS failure, or the server is unreachable.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// The request took too long.
class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

/// 401 — credentials missing, invalid, or expired.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Please sign in again.']);
}

/// 403 — authenticated but not permitted.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
    super.message = 'You do not have permission to do this.',
  ]);
}

/// 404 — resource does not exist.
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}

/// 422 — the backend rejected the submitted fields.
class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code,
    super.details,
  });
}

/// 5xx — the backend failed.
class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

/// Anything not covered above.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}
