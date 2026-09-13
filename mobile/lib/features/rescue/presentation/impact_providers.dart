import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/food_listing.dart';
import '../domain/impact_summary.dart';
import '../domain/rescue.dart';
import 'listing_providers.dart';
import 'rescue_providers.dart';

/// The consumer's impact, computed from what actually completed.
///
/// Every figure here is a count or a sum of real records — completed rescues
/// and completed listings the user published. Nothing is estimated.
///
/// **Weight is deliberately absent.** The Give flow never asks for one, so
/// `weight_kg` is null on essentially every listing, and "kg of food diverted"
/// cannot be computed honestly. It is reported as unknown rather than guessed;
/// see `docs/API.md` for the dependency the Zero-Waste work will have on it.
class ConsumerImpact {
  const ConsumerImpact({required this.summary, required this.recent});

  final ImpactSummary summary;
  final List<ImpactEntry> recent;

  /// True when there is genuinely nothing yet, so the screen can say so
  /// instead of showing a wall of zeroes.
  bool get isEmpty => summary.rescues == 0 && summary.shares == 0;
}

final consumerImpactProvider = FutureProvider.autoDispose<ConsumerImpact>((
  ref,
) async {
  // Concurrently: these two read different endpoints and neither needs the
  // other's answer. Awaiting them in turn cost the sum of two round trips
  // (~2s against the deployed API) for a screen that could have paid one.
  final results = await Future.wait([
    ref.watch(myRescuesProvider.future),
    ref.watch(myListingsProvider.future),
  ]);
  final rescues = results[0] as List<Rescue>;
  final listings = results[1] as List<FoodListing>;

  final completedRescues = rescues
      .where((r) => r.status == 'completed')
      .toList(growable: false);
  final completedShares = listings
      .where((l) => l.status == 'completed')
      .toList(growable: false);

  return ConsumerImpact(
    summary: ImpactSummary(
      mealBoxes: completedRescues.fold(
        0,
        (total, r) => total + _mealBoxes(r.listing),
      ),
      rescues: completedRescues.length,
      servings: completedRescues.fold(
        0,
        (total, r) => total + r.listing.servings,
      ),
      shares: completedShares.length,
      rangeLabel: 'All time',
      lastUpdatedLabel: 'Updated just now',
    ),
    recent: [
      for (final rescue in completedRescues)
        ImpactEntry(
          title: rescue.listing.title,
          kind: ImpactEntryKind.rescued,
          whenLabel: rescue.listing.pickupWindow,
        ),
      for (final listing in completedShares)
        ImpactEntry(
          title: listing.title,
          kind: ImpactEntryKind.shared,
          whenLabel: listing.pickupWindow,
        ),
    ],
  );
});

/// Only listings actually counted in meal boxes contribute to that headline —
/// servings and kilograms are different things and are not silently converted.
int _mealBoxes(FoodListing listing) {
  if (listing.unit != 'meal_boxes') return 0;
  return listing.quantityCount ?? 0;
}

/// How many rescues the signed-in consumer has completed. Backs Home's
/// impact preview.
final completedRescueCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final impact = await ref.watch(consumerImpactProvider.future);
  return impact.summary.rescues;
});
