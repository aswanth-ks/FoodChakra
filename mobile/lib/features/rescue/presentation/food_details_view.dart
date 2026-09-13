import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../domain/food_listing.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loader_view.dart';
import 'food_details_screen.dart';
import 'listing_providers.dart';
import 'rescue_providers.dart';
import 'widgets/rescue_confirmation_sheet.dart';

/// Connects [FoodDetailsScreen] to the listing and the claim endpoint.
///
/// A connector, not a screen: it owns no layout. Its one piece of state is
/// whether a claim is in flight, which is what stops a second tap becoming a
/// second claim — the endpoint is not idempotent, and the confirmation sheet
/// only guards the first press.
class FoodDetailsView extends ConsumerStatefulWidget {
  const FoodDetailsView({
    super.key,
    required this.listingId,
    this.initial,
    this.onBack,
    this.onClaimed,
  });

  final String listingId;

  /// The listing as the previous screen already had it.
  ///
  /// Explore and Home have just rendered this card, so the data exists on the
  /// device before the tap. Showing it at once turns a round trip's worth of
  /// spinner into an instant screen. The server is still asked, and its answer
  /// still replaces this — the listing may have been claimed or withdrawn in
  /// the meantime, and only the server knows that.
  ///
  /// Null on a cold path, such as a deep link, where nothing is known yet.
  final FoodListing? initial;

  final VoidCallback? onBack;

  /// Receives the **server's** rescue id. Nothing is invented locally: until
  /// the backend answers there is no rescue.
  final void Function(String rescueId)? onClaimed;

  @override
  ConsumerState<FoodDetailsView> createState() => _FoodDetailsViewState();
}

class _FoodDetailsViewState extends ConsumerState<FoodDetailsView> {
  bool _claiming = false;

  /// Claims the listing, then opens the rescue the server created.
  ///
  /// A refused claim is the normal case rather than a malfunction: someone
  /// else got there first. The server's own wording is shown, and the listing
  /// is re-read either way — leaving a claimable-looking card on screen after
  /// the server has said otherwise is how a user ends up tapping it again.
  Future<void> _claim(FoodListing listing) async {
    if (_claiming) return;

    final confirmed = await showRescueConfirmationSheet(
      context,
      listing: listing,
    );
    if (!(confirmed ?? false) || !mounted) return;

    setState(() => _claiming = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final rescue = await ref
          .read(rescueRepositoryProvider)
          .claim(widget.listingId);

      // The listing has left the pool, so Explore must not keep offering it.
      ref.invalidate(nearbyListingsProvider);
      ref.invalidate(myRescuesProvider);
      if (!mounted) return;
      widget.onClaimed?.call(rescue.id);
    } on Failure catch (failure) {
      // A conflict or a vanished listing means this screen is out of date.
      // Re-reading it is what turns a stale rescue button into the real
      // unavailable state.
      if (failure is ConflictFailure || failure is NotFoundFailure) {
        ref.invalidate(listingDetailProvider(widget.listingId));
        ref.invalidate(nearbyListingsProvider);
      }
      messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listingDetailProvider(widget.listingId));

    // The server's copy when it has arrived, otherwise what the previous
    // screen already knew. Never both: the server always wins once it answers.
    final listing = async.value ?? widget.initial;

    // An error only takes the screen when there is nothing to show. With a
    // listing already on screen, a failed refresh is not worth replacing it
    // with an error page — except a 404, which means the thing genuinely is
    // not there any more and acting on it would waste the user's journey.
    final error = async.error;
    if (error != null && (listing == null || error is NotFoundFailure)) {
      return ErrorStateView(
        error: error,
        // A listing someone else has just claimed, or one that expired while
        // this screen was open, comes back as a 404. That is not a
        // malfunction and should not read like one.
        title: error is NotFoundFailure
            ? 'This food is no longer available'
            : null,
        onRetry: () => ref.invalidate(listingDetailProvider(widget.listingId)),
      );
    }

    if (listing == null) return const LoaderView();

    return FoodDetailsScreen(
      listing: listing,
      rescuing: _claiming,
      onBack: widget.onBack,
      onRescue: () => _claim(listing),
    );
  }
}
