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

/// 403 with `EMAIL_NOT_VERIFIED` — the password was right, but the address
/// has never been confirmed.
///
/// A subclass of [ForbiddenFailure] so anything that already treats a 403 as
/// "this session is over" keeps working, while the sign-in screen can pick it
/// out and open the verification screen instead of showing a refusal.
class EmailNotVerifiedFailure extends ForbiddenFailure {
  const EmailNotVerifiedFailure([
    super.message = 'Verify your email address to sign in.',
  ]);
}

/// 429 — a code was guessed too often, or asked for again too soon.
class TooManyAttemptsFailure extends Failure {
  const TooManyAttemptsFailure([
    super.message = 'Too many attempts. Please try again in a moment.',
  ]);
}

/// 503 — a dependency the backend needs is down.
///
/// Distinct from [ServerFailure] because it is the honest answer when email
/// cannot be delivered: nothing was sent, and the user needs to be told that
/// rather than shown a success screen.
class ServiceUnavailableFailure extends Failure {
  const ServiceUnavailableFailure([
    super.message = 'That service is unavailable right now.',
  ]);
}

/// 404 — resource does not exist.
/// 409 — the thing is no longer in the state the request assumed.
///
/// Tap-to-claim's normal loser: someone else took the listing first. Distinct
/// from [UnknownFailure], which it used to fall through to, so a caller can
/// refresh the stale view rather than only apologising.
class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'That is no longer available.']);
}

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
