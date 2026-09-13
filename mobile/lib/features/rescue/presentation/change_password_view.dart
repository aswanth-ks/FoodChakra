import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/failures.dart';
import '../../auth/presentation/auth_providers.dart';
import 'change_password_screen.dart';

/// Connects [ChangePasswordScreen] to the account endpoint.
///
/// Nothing typed on the screen is kept here. The two values are passed
/// straight to the repository and never stored, logged or put in a snackbar.
class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<ChangePasswordView> createState() =>
      _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  bool _saving = false;
  Object? _error;

  /// Changes the password, which ends the session on purpose.
  ///
  /// The server revokes every refresh session, so the controller signs out
  /// locally too and the router's redirect takes the user to sign-in. No
  /// navigation is done here: leaving the app believing in a session the
  /// server has already destroyed is how a screen fills with 401s.
  Future<void> _submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Password changed. Please sign in again.'),
        ),
      );
    } on Failure catch (failure) {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangePasswordScreen(
      saving: _saving,
      error: _error,
      onBack: widget.onBack,
      onSubmit: _submit,
    );
  }
}
