import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/failures.dart';
import '../../../shared/widgets/loader_view.dart';
import '../../auth/presentation/auth_providers.dart';
import 'edit_profile_screen.dart';

/// Connects [EditProfileScreen] to the account endpoint.
///
/// Owns one piece of state: whether a save is in flight. That is what stops a
/// second tap becoming a second request, and what the screen shows a spinner
/// for.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key, this.onBack, this.onSaved});

  final VoidCallback? onBack;

  /// Where to go once the server has accepted the change. Supplied by the
  /// router, like every other destination in this app — a connector that
  /// navigates by itself is a second place to look when routing goes wrong.
  final VoidCallback? onSaved;

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  bool _saving = false;
  Object? _error;

  /// Saves the name, then leaves.
  ///
  /// The notifier publishes whatever the server returned, so Profile behind
  /// this screen is already showing the stored value by the time the pop
  /// completes — there is no local copy to go stale, and nothing is shown as
  /// saved that the server did not accept.
  Future<void> _save(String fullName) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    // Captured before the await. Saving changes the session, which refreshes
    // the router, which can rebuild this subtree — reading `widget` afterwards
    // is reading a widget that may no longer be the mounted one, and the
    // navigation would silently never happen.
    final onSaved = widget.onSaved;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(fullName: fullName);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      onSaved?.call();
    } on Failure catch (failure) {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authControllerProvider).value;
    // The gate has already refused an unauthenticated visitor; this only
    // covers the frame in which a sign-out is settling.
    if (account == null) return const LoaderView();

    return EditProfileScreen(
      initialName: account.fullName,
      email: account.email,
      saving: _saving,
      error: _error,
      onBack: widget.onBack,
      onSave: _save,
    );
  }
}
