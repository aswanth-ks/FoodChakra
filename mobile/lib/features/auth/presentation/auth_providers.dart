import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/dio_client.dart';
import '../data/auth_repository_impl.dart';
import '../domain/account.dart';
import '../domain/auth_repository.dart';

/// Binds the repository interface to its implementation.
///
/// Tests override this with a fake, which is why the presentation layer only
/// ever references the interface.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// The signed-in account, or null when signed out.
///
/// This notifier is the **only** place the app learns who is signed in and
/// what role they hold. Nothing infers either from the email address — see
/// `AccountRole` for why that was removed.
class AuthController extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() => ref.watch(authRepositoryProvider).restoreSession();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Signs in and returns the account, so the caller can route by its role.
  ///
  /// Rethrows the `Failure` after recording it, letting the caller show a
  /// message while the notifier still reflects the failed state.
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final account = await _repository.signIn(email: email, password: password);
      state = AsyncValue.data(account);
      return account;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Creates an account. Deliberately does **not** sign anyone in.
  ///
  /// The notifier's state is untouched, because registering produces no
  /// session: the server issues no tokens for an address it has not yet
  /// confirmed. Setting `state` to an account here would let the router's
  /// gate wave the user straight into the app, which is exactly the hole
  /// email verification exists to close.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) => _repository.register(
    fullName: fullName,
    email: email,
    password: password,
  );

  /// Confirms an address. Still no session — the user signs in next.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) => _repository.verifyEmail(email: email, code: code);

  Future<void> resendVerification(String email) =>
      _repository.resendVerification(email);

  Future<void> forgotPassword(String email) =>
      _repository.forgotPassword(email);

  /// Sets a new password. Every existing session is revoked server-side, so
  /// the local one is cleared too rather than left pointing at dead tokens.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _repository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    if (state.value != null) {
      await _repository.signOut();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Account?>(AuthController.new);
