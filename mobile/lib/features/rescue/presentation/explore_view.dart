import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/consumer_nav_bar.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loader_view.dart';
import '../domain/food_listing.dart';
import 'explore_screen.dart';
import 'listing_providers.dart';

/// Connects [ExploreScreen] to the listings API.
///
/// Owns the selected filter chip so the choice reaches the query rather than
/// only the chip's appearance.
class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({
    super.key,
    this.onOpenListing,
    this.onSelectTab,
  });

  final void Function(FoodListing listing)? onOpenListing;
  final void Function(ConsumerTab tab)? onSelectTab;

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  String _filter = ExploreScreen.filters.first;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exploreListingsProvider(_filter));

    return async.when(
      loading: () => const LoaderView(),
      error: (error, _) => ErrorStateView(
        error: error,
        onRetry: () => ref.invalidate(exploreListingsProvider(_filter)),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          // An empty result is not an error and does not get the error view.
          return EmptyStateView(
            title: 'Nothing to rescue right now',
            message: _filter == ExploreScreen.filters.first
                ? 'No surplus food is available nearby yet. Check back a '
                      'little later.'
                : 'No surplus food matches "$_filter" nearby. Try a '
                      'different filter.',
            actionLabel: 'Refresh',
            onAction: () => ref.invalidate(exploreListingsProvider(_filter)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(exploreListingsProvider(_filter));
            await ref.read(exploreListingsProvider(_filter).future);
          },
          child: ExploreScreen(
            listings: listings,
            location: listings.first.pickupLocality ?? 'Near you',
            newOpportunityCount: listings.length,
            selectedFilter: _filter,
            onSelectFilter: (filter) => setState(() => _filter = filter),
            onOpenListing: widget.onOpenListing,
            onSelectTab: widget.onSelectTab,
          ),
        );
      },
    );
  }
}
