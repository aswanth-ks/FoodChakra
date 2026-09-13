import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/geo_point.dart';
import '../../../shared/widgets/consumer_nav_bar.dart';
import '../domain/food_listing.dart';
import 'explore_screen.dart';
import 'listing_providers.dart';

/// Connects [ExploreScreen] to the listings API.
///
/// Owns the selected filter chip so the choice reaches the query rather than
/// only the chip's appearance.
///
/// The screen is built in every state — loading, failed, empty and populated
/// alike — and the async state is handed to it rather than unwrapped here.
/// Swapping the whole screen for a spinner or an error view also removed the
/// filter chips, so a filter that matched nothing left no way back to one that
/// did; the results area alone now changes.
class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({
    super.key,
    this.onOpenListing,
    this.onSelectTab,
    this.initialView = ExploreResultView.list,
  });

  final void Function(FoodListing listing)? onOpenListing;
  final void Function(ConsumerTab tab)? onSelectTab;

  /// Which results view to open on. Home's map card asks for the map.
  final ExploreResultView initialView;

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  String _filter = ExploreScreen.filters.first;

  bool get _isDefaultFilter => _filter == ExploreScreen.filters.first;

  /// Drops the cached answer *and* the provider it is derived from.
  ///
  /// The default chip delegates to [nearbyListingsProvider], and a failed
  /// provider caches its error: invalidating only the derived one would
  /// recompute from the same cached failure and never reach the network,
  /// leaving a "Try again" button that does nothing.
  void _invalidateResults() {
    ref.invalidate(exploreListingsProvider(_filter));
    ref.invalidate(nearbyListingsProvider);
  }

  /// Refetches from the backend rather than re-rendering what is cached, so a
  /// listing someone else has just claimed disappears on the next pull.
  Future<void> _reload() async {
    _invalidateResults();
    try {
      await ref.read(exploreListingsProvider(_filter).future);
    } on Object {
      // The failure is already in the provider's state, and the screen shows
      // it. Rethrowing here would only surface an unhandled error from the
      // refresh gesture.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exploreListingsProvider(_filter));
    final listings = async.value ?? const <FoodListing>[];

    // The same origin the query was made from, so the map's "you" dot and the
    // distances on the cards cannot disagree.
    final origin = ref.watch(currentOriginProvider);
    final point = origin.hasValue
        ? GeoPoint.tryFrom(origin.value!.latitude, origin.value!.longitude)
        : null;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ExploreScreen(
        listings: listings,
        // The locality of the nearest result is the honest answer to "where
        // are you looking?" — there is nothing to say before one arrives.
        location: listings.isEmpty
            ? 'Near you'
            : (listings.first.pickupLocality ?? 'Near you'),
        newOpportunityCount: async.hasValue ? listings.length : 0,
        resultsLoading: async.isLoading,
        resultsError: async.error,
        onRetry: _invalidateResults,
        origin: point,
        initialView: widget.initialView,
        emptyMessage: _isDefaultFilter
            ? null
            : 'No surplus food matches "$_filter" nearby. Try a different '
                  'filter.',
        selectedFilter: _filter,
        onSelectFilter: (filter) => setState(() => _filter = filter),
        onOpenListing: widget.onOpenListing,
        onSelectTab: widget.onSelectTab,
      ),
    );
  }
}
