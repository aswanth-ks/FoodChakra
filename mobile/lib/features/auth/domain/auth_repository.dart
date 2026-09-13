import 'account.dart';

/// Repository contract owned by the domain layer.
///
/// The presentation layer depends on this interface, never the implementation,
/// so tests run with a fake and no HTTP.
abstract interface class AuthRepository {
  /// Creates a consumer account and asks the server to email a code.
  ///
  /// Returns no [Account] and no session, because the server issues neither:
  /// the address is unproven until the code comes back, so the caller's next
  /// stop is the verification screen, not the app.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  });

  /// Confirms an address with the 6-digit code that was emailed.
  ///
  /// Throws a `ValidationFailure` for a wrong, expired or already-used code —
  /// the server deliberately does not say which.
  Future<void> verifyEmail({required String email, required String code});

  /// Asks for a fresh verification code, invalidating the previous one.
  Future<void> resendVerification(String email);

  /// Starts a password reset. Succeeds whether or not the address is
  /// registered: the server answers identically either way, on purpose.
  Future<void> forgotPassword(String email);

  /// Sets a new password with a reset code. No session is issued — the user
  /// signs in again with what they just chose.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<Account> signIn({required String email, required String password});

  /// Restores a stored session, or null when there is none or it has expired.
  Future<Account?> restoreSession();

  /// Renames the signed-in account and returns it as the server now holds it.
  ///
  /// The account is identified by the access token, so there is no id to pass
  /// and no way to name somebody else's.
  Future<Account> updateProfile({required String fullName});

  /// Replaces the password for someone who can prove they know the current
  /// one. The server revokes every session on success, so the caller must
  /// sign in again afterwards.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();
}
