import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loader_view.dart';
import 'handover_confirmation_screen.dart';
import 'listing_providers.dart';
import 'rescue_providers.dart';

/// Connects [HandoverConfirmationScreen] to the rescue on the owner's listing.
///
/// Routed by **listing** id, not rescue id: the owner knows their own surplus,
/// and the server resolves which rescue is holding it. That also means the
/// owner never has to be handed a rescue id they had no way to know.
class HandoverConfirmationView extends ConsumerStatefulWidget {
  const HandoverConfirmationView({
    super.key,
    required this.listingId,
    this.onBack,
    this.onDone,
  });

  final String listingId;
  final VoidCallback? onBack;
  final VoidCallback? onDone;

  @override
  ConsumerState<HandoverConfirmationView> createState() =>
      _HandoverConfirmationViewState();
}

class _HandoverConfirmationViewState
    extends ConsumerState<HandoverConfirmationView> {
  bool _submitting = false;
  bool _verified = false;
  String? _error;

  /// Submits the code the rescuer read out.
  ///
  /// Success is never assumed locally — the screen only shows a confirmed
  /// handover after the server has said so. A wrong, expired or already-used
  /// code surfaces the backend's own message, which is the one that knows
  /// which of those it was.
  Future<void> _confirm(String rescueId, String code) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(rescueRepositoryProvider)
          .verifyHandover(rescueId, code: code);
      if (!mounted) return;
      setState(() => _verified = true);
      ref.invalidate(rescueForListingProvider(widget.listingId));
      ref.invalidate(myListingsProvider);
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rescueForListingProvider(widget.listingId));

    return async.when(
      loading: () => const LoaderView(),
      error: (error, _) => ErrorStateView(
        error: error,
        onRetry: () =>
            ref.invalidate(rescueForListingProvider(widget.listingId)),
      ),
      data: (rescue) => HandoverConfirmationScreen(
        rescue: rescue,
        submitting: _submitting,
        // Already verified server-side counts too, so re-opening the screen
        // after a confirmation shows the confirmed state rather than asking
        // for the code again.
        verified: _verified || rescue.status == 'verified',
        errorMessage: _error,
        onBack: widget.onBack,
        onDone: widget.onDone,
        onConfirm: (code) => _confirm(rescue.id, code),
      ),
    );
  }
}
