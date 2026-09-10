import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loader_view.dart';
import '../domain/food_listing.dart';
import '../domain/rescue.dart';
import 'active_rescue_screen.dart';
import 'listing_providers.dart';
import 'rescue_providers.dart';

/// Connects [ActiveRescueScreen] to the live rescue.
///
/// A connector, not a screen: it owns no layout. Its one piece of state is the
/// handover code, held here **in memory only**. The server issues it exactly
/// once, so leaving this screen drops it rather than keeping a copy that could
/// be shown again — there is deliberately no way to ask for it back.
class ActiveRescueView extends ConsumerStatefulWidget {
  const ActiveRescueView({
    super.key,
    required this.rescueId,
    this.onBack,
    this.onCancelled,
    this.onCompleted,
  });

  final String rescueId;
  final VoidCallback? onBack;
  final VoidCallback? onCancelled;
  final void Function(String rescueId)? onCompleted;

  @override
  ConsumerState<ActiveRescueView> createState() => _ActiveRescueViewState();
}

class _ActiveRescueViewState extends ConsumerState<ActiveRescueView> {
  String? _handoverCode;
  bool _busy = false;

  /// Runs a rescue mutation, then re-reads the rescue from the server.
  ///
  /// Nothing advances the stepper locally: the screen only ever shows the
  /// state the backend reported, so a rejected transition cannot leave the UI
  /// claiming progress that did not happen.
  Future<void> _mutate(Future<Rescue> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final updated = await action();
      if (updated.handoverCode != null) {
        setState(() => _handoverCode = updated.handoverCode);
      }
      ref.invalidate(rescueDetailProvider(widget.rescueId));
      ref.invalidate(myRescuesProvider);
      ref.invalidate(nearbyListingsProvider);
    } on Failure catch (failure) {
      messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rescueDetailProvider(widget.rescueId));
    final repository = ref.read(rescueRepositoryProvider);

    return async.when(
      loading: () => const LoaderView(),
      error: (error, _) => ErrorStateView(
        error: error,
        onRetry: () => ref.invalidate(rescueDetailProvider(widget.rescueId)),
      ),
      data: (rescue) => ActiveRescueScreen(
        listing: rescue.listing,
        // The stepper follows the server's canonical status.
        stage: rescue.stage ?? RescueStage.confirmed,
        handoverCode: _handoverCode,
        onBack: widget.onBack,
        // Each forward action is offered only in the state the backend
        // accepts it from. Opening maps is not one of them: it mutates
        // nothing, so a rescuer who looks at the route and changes their mind
        // leaves the rescue exactly as it was.
        onOnTheWay: rescue.status == 'matched' && !_busy
            ? () => _mutate(() => repository.startTravel(rescue.id))
            : null,
        onArrived: rescue.status == 'onTheWay' && !_busy
            ? () => _mutate(() => repository.markArrived(rescue.id))
            : null,
        onCollected: rescue.status == 'verified' && !_busy
            ? () async {
                await _mutate(() => repository.markCollected(rescue.id));
                if (!mounted) return;
                final refreshed = await ref.read(
                  rescueDetailProvider(widget.rescueId).future,
                );
                if (refreshed.status == 'completed') {
                  widget.onCompleted?.call(rescue.id);
                }
              }
            : null,
        onCancelRescue: _busy
            ? null
            : () async {
                await _mutate(() => repository.cancel(rescue.id));
                widget.onCancelled?.call();
              },
      ),
    );
  }
}
