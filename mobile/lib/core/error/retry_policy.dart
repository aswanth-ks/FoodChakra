import 'dart:math' as math;

import '../location/location_providers.dart';
import 'failures.dart';

/// How Riverpod retries a provider that failed.
///
/// Riverpod 3 retries every failed provider by default: ten attempts, backing
/// off from 200ms to 6.4s. For a provider that fails because of a bad network
/// that is reasonable. For the two cases below it is actively harmful, and on
/// a real device it was the single worst thing in the app.
///
/// **Location.** A refused or unanswered permission prompt surfaced as a
/// failure, which Riverpod retried, which asked the platform again, which put
/// the system permission dialog back on screen — a loop measured at one
/// ten-second GPS attempt every ten seconds, re-prompting each time. Waiting
/// cannot fix a permission; only the user can, and the screens already offer
/// them a way to. Retrying it is wrong in principle and awful in practice.
///
/// **Requests the server refused on purpose.** A 401, a 403, a 404 or a
/// conflict is a considered answer, not a blip. Asking nine more times cannot
/// change it and costs the user nine round trips.
///
/// What is left — a dropped connection, a timeout, a 5xx — is worth retrying,
/// but far less eagerly than ten times: each attempt against this backend
/// costs about a second, so the old policy could spend the better part of a
/// minute before giving up, with nothing on screen explaining why.
Duration? foodloopRetry(int retryCount, Object error) {
  // Needs a person, not another attempt.
  if (error is LocationUnavailable) return null;

  // The server has answered, and the answer will not change.
  if (error is UnauthorizedFailure ||
      error is ForbiddenFailure ||
      error is NotFoundFailure ||
      error is ConflictFailure ||
      error is ValidationFailure) {
    return null;
  }

  // A programming mistake is not a transient condition.
  if (error is Error) return null;

  // Two retries, then the screen shows its error state and offers a manual
  // "Try again" — which is more honest than a long silent loop, and lets the
  // user decide whether it is worth waiting.
  const maxRetries = 2;
  if (retryCount >= maxRetries) return null;

  const minDelay = Duration(milliseconds: 250);
  final delay = minDelay * math.pow(2, retryCount).toInt();
  return delay > const Duration(seconds: 2) ? const Duration(seconds: 2) : delay;
}
