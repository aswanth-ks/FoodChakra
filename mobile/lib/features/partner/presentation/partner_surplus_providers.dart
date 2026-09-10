import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rescue/domain/food_listing.dart';
import '../../rescue/presentation/listing_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/partner_dashboard.dart';

/// The partner dashboard, computed from the partner's own listings.
///
/// Every count here is derived from real records returned by `/listings/mine`.
/// Nothing is a fixture, and nothing is estimated.
///
/// **The business profile is the one thing the backend cannot yet supply.**
/// A partner's trading name, category and locality arrive with the partner
/// grant, which the operations console issues — and neither the grant nor a
/// `/partners/me` endpoint exists. The signed-in account's own name stands in,
/// which is at least true, rather than a fictional restaurant.
final partnerDashboardProvider = FutureProvider.autoDispose<PartnerDashboard>((
  ref,
) async {
  final listings = await ref.watch(myListingsProvider.future);
  final account = ref.watch(authControllerProvider).value;

  final active = [
    for (final listing in listings.where(_isLive)) _toSurplus(listing),
  ];
  final past = [
    for (final listing in listings.where(_isFinished)) _toSurplus(listing),
  ];

  final claimed = active.where((s) => s.status.isClaimed).toList();
  final completed = listings
      .where((l) => l.status == 'completed')
      .toList(growable: false);

  // The batch closing soonest, which is what the alert banner is about.
  final soonest = [...active]
    ..sort(
      (a, b) => (a.minutesLeft ?? 1 << 30).compareTo(b.minutesLeft ?? 1 << 30),
    );
  final urgent = soonest.isEmpty ? null : soonest.first;

  return PartnerDashboard(
    profile: PartnerProfile(
      name: account?.fullName ?? 'Your business',
      category: 'FoodLoop Partner',
      // The account carries no locality, so nothing is claimed about one.
      locality: 'Partner account',
    ),
    // Portions actually handed over, summed from completed listings.
    portionsShared: completed.fold(0, (total, l) => total + l.servings),
    batchCount: active.length,
    activeRescues: claimed.length,
    matchedCount: claimed.length,
    pickupSoonCount: urgent == null ? 0 : 1,
    pickupSoonMinutes: urgent?.minutesLeft ?? 0,
    pickupSoonDetail: urgent?.title ?? 'Nothing closing soon',
    rescuesComplete: completed.length,
    completionRate: _completionRate(listings),
    activeSurplus: active,
    pastSurplus: past,
    // Derived from real listings; empty until something completes, rather
    // than borrowing someone else's activity feed.
    recentActivity: [
      for (final listing in completed.take(5))
        PartnerActivityRow(
          title: listing.title,
          subtitle: 'Rescue completed · ${listing.pickupLocation}',
          badgeLabel: 'Collected',
          completed: true,
        ),
    ],
  );
});

/// Share of finished listings that were actually collected, 0 when nothing has
/// finished yet — an empty history has no rate, and 100% would be a lie.
int _completionRate(List<FoodListing> listings) {
  final finished = listings.where(_isFinished).length;
  if (finished == 0) return 0;
  final completed = listings.where((l) => l.status == 'completed').length;
  return ((completed / finished) * 100).round();
}

bool _isLive(FoodListing listing) => switch (listing.status) {
  'published' || 'searching' || 'matched' => true,
  _ => false,
};

bool _isFinished(FoodListing listing) => switch (listing.status) {
  'collected' || 'completed' || 'expired' || 'cancelled' => true,
  _ => false,
};

/// Maps a listing onto the partner card model.
///
/// The status projection mirrors the backend's own mapping table
/// (`lifecycle.py`), so the two cannot disagree about what "matched" looks
/// like to a partner.
PartnerSurplus _toSurplus(FoodListing listing) => PartnerSurplus(
  // The real listing id, which is what makes the handover route resolvable.
  id: listing.id,
  title: listing.title,
  status: _statusFor(listing.status),
  imageAsset: listing.imageAsset,
  windowLabel: listing.pickupWindow,
  detailLine: '${listing.category} · ${listing.quantity}',
  locationLine: listing.isClaimed
      ? '${listing.pickupLocation} · Rescuer on the way'
      : listing.pickupLocation,
  minutesLeft: listing.timeRemaining?.inMinutes,
);

PartnerSurplusStatus _statusFor(String? status) => switch (status) {
  'draft' => PartnerSurplusStatus.draft,
  'matched' || 'onTheWay' => PartnerSurplusStatus.rescuerMatched,
  'arrived' || 'verified' => PartnerSurplusStatus.awaitingHandover,
  'collected' || 'completed' => PartnerSurplusStatus.collected,
  'expired' => PartnerSurplusStatus.expired,
  _ => PartnerSurplusStatus.lookingForRescuer,
};

extension on PartnerSurplusStatus {
  /// Whether someone has claimed this batch, so a handover is coming.
  bool get isClaimed =>
      this == PartnerSurplusStatus.rescuerMatched ||
      this == PartnerSurplusStatus.awaitingHandover;
}
