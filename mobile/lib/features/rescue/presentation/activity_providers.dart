import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity_item.dart';
import '../domain/food_listing.dart';
import '../domain/rescue.dart';
import 'listing_providers.dart';
import 'rescue_providers.dart';

/// The Activity screen's "Active" feed, built from the two things a consumer
/// can have in flight: food they are rescuing, and food they have shared.
///
/// This is also how a food owner **discovers** that someone is coming for
/// their surplus. FoodLoop sends no notifications, so without this entry point
/// an owner would have no way to reach the handover confirmation at all.
final activeActivityProvider = FutureProvider.autoDispose<List<ActivityItem>>((
  ref,
) async {
  // Concurrently: two independent endpoints, so the screen waits for the
  // slower of the two rather than for both in turn.
  final results = await Future.wait([
    ref.watch(myRescuesProvider.future),
    ref.watch(myListingsProvider.future),
  ]);
  final rescues = results[0] as List<Rescue>;
  final listings = results[1] as List<FoodListing>;

  return [
    // Food I am collecting.
    for (final rescue in rescues.where((r) => r.isActive))
      _fromRescue(rescue),
    // Food I have shared, and whether anyone is coming for it.
    for (final listing in listings.where(_isInFlight)) _fromListing(listing),
  ];
});

/// A shared listing is "in flight" while it is still findable or claimed.
/// Completed, cancelled and expired listings belong on the History tab.
bool _isInFlight(FoodListing listing) => switch (listing.status) {
  'published' || 'searching' || 'matched' => true,
  _ => false,
};

/// The Activity screen's "History" tab: rescues and shares that finished.
final activityHistoryProvider =
    FutureProvider.autoDispose<List<ActivityHistoryEntry>>((ref) async {
      final results = await Future.wait([
        ref.watch(myRescuesProvider.future),
        ref.watch(myListingsProvider.future),
      ]);
      final rescues = results[0] as List<Rescue>;
      final listings = results[1] as List<FoodListing>;

      return [
        for (final rescue in rescues.where((r) => r.status == 'completed'))
          ActivityHistoryEntry(
            title: rescue.listing.title,
            subtitle: 'Collected · ${rescue.listing.pickupLocation}',
            outcomeLabel: 'Collected',
          ),
        for (final listing in listings.where(_isFinishedShare))
          ActivityHistoryEntry(
            title: listing.title,
            subtitle: '${_outcomeFor(listing)} · ${listing.pickupLocation}',
            outcomeLabel: _outcomeFor(listing),
          ),
      ];
    });

bool _isFinishedShare(FoodListing listing) => switch (listing.status) {
  'completed' || 'expired' || 'cancelled' => true,
  _ => false,
};

/// Says what actually happened rather than calling everything a success — an
/// expired listing is not a rescue.
String _outcomeFor(FoodListing listing) => switch (listing.status) {
  'completed' => 'Shared',
  'expired' => 'Expired',
  _ => 'Withdrawn',
};

ActivityItem _fromRescue(Rescue rescue) {
  final listing = rescue.listing;
  return ActivityItem(
    // Keyed by rescue id: opening this goes to the rescue, not the listing.
    id: rescue.id,
    kind: ActivityKind.rescue,
    status: ActivityStatus.readyForPickup,
    title: listing.title,
    categoryLabel: listing.category,
    imageAsset: listing.imageAsset,
    detailLine: listing.pickupWindow,
    timeRemaining: listing.timeRemaining,
    locationLine: '${listing.pickupLocation} · ${listing.distanceLabel}',
  );
}

ActivityItem _fromListing(FoodListing listing) {
  final claimed = listing.isClaimed;
  return ActivityItem(
    // Keyed by listing id: the owner's actions are about their listing, and
    // the server resolves which rescue is holding it.
    id: listing.id,
    kind: ActivityKind.share,
    status: claimed
        ? ActivityStatus.rescuerArriving
        : ActivityStatus.lookingForRescuer,
    title: listing.title,
    categoryLabel: listing.category,
    imageAsset: listing.imageAsset,
    detailLine: listing.pickupWindow,
    timeRemaining: listing.timeRemaining,
    note: claimed
        ? 'A rescuer is on their way — confirm the handover when they arrive.'
        : 'We are letting nearby rescuers know.',
  );
}
