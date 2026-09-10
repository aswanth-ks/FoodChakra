/// The signed-in business.
///
/// Phase 3 fills this from the account's partner grant; the ops console is
/// where a restaurant, caterer or hotel is given that grant in the first
/// place, so none of it is editable from the app.
class PartnerProfile {
  const PartnerProfile({
    required this.name,
    required this.category,
    required this.locality,
    this.isOpen = true,
  });

  /// "Green Leaf Kitchen".
  final String name;

  /// "Restaurant Partner".
  final String category;

  /// "Downtown".
  final String locality;

  /// Drives the green dot beside the name.
  final bool isOpen;

  /// "Restaurant Partner · Downtown".
  String get subtitle => '$category · $locality';
}

/// Which list the Surplus screen is showing.
enum PartnerSurplusTab {
  active('Active'),
  drafts('Drafts'),
  history('History');

  const PartnerSurplusTab(this.label);

  final String label;
}

/// How far along a piece of the partner's surplus is.
enum PartnerSurplusStatus {
  lookingForRescuer('Looking for rescuer'),
  rescuerMatched('Rescuer matched'),
  awaitingHandover('Awaiting handover'),
  draft('Draft'),
  collected('Collected'),
  expired('Expired');

  const PartnerSurplusStatus(this.label);

  final String label;
}

/// One batch of surplus the partner currently has live.
class PartnerSurplus {
  const PartnerSurplus({
    required this.id,
    required this.title,
    required this.status,
    required this.imageAsset,
    required this.windowLabel,
    this.detailLine,
    this.locationLine,
    this.pickupPoint,
    this.minutesLeft,
  });

  final String id;

  /// "25 Meal Boxes".
  final String title;

  final PartnerSurplusStatus status;
  final String imageAsset;

  /// "Today · 7:30 PM–8:30 PM" on the full card, "Until 9:15 PM" on the
  /// compact one.
  final String windowLabel;

  /// "Vegetarian · Approx. 25 servings". Absent on the compact card.
  final String? detailLine;

  /// "Community Hall · Rescuer arriving". Shown on the dashboard card.
  final String? locationLine;

  /// "Pickup counter · Main entrance". Shown on the Surplus screen's card,
  /// where the partner needs the handover point rather than the rescuer's
  /// progress.
  final String? pickupPoint;

  final int? minutesLeft;

  /// A matched batch gets the full card; anything still matching gets the
  /// compact row, as in the design.
  bool get isPrimary => status == PartnerSurplusStatus.rescuerMatched;

  /// "42 min left".
  String? get countdownLabel =>
      minutesLeft == null ? null : '$minutesLeft min left';

  /// "42 min remaining" — the Surplus screen's longer wording.
  String? get remainingLabel =>
      minutesLeft == null ? null : '$minutesLeft min remaining';

  /// Whether the batch is still open for collection.
  bool get isLive =>
      status == PartnerSurplusStatus.lookingForRescuer ||
      status == PartnerSurplusStatus.rescuerMatched ||
      status == PartnerSurplusStatus.awaitingHandover;

  /// The card's action.
  String get actionLabel => isPrimary ? 'View rescue' : 'View status';
}

/// One row in the "Recent activity" list.
class PartnerActivityRow {
  const PartnerActivityRow({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.completed,
  });

  final String title;

  /// "Rescue completed · 10 min ago".
  final String subtitle;

  /// "Collected ✓" / "Archived".
  final String badgeLabel;

  /// Green treatment for a completed rescue, neutral for an archived share.
  final bool completed;
}

/// Everything Partner Home renders in one shot.
///
/// Built by `partnerDashboardProvider` from the partner's own listings. The
/// screen takes it as a parameter, so it never reads the network itself.
class PartnerDashboard {
  const PartnerDashboard({
    required this.profile,
    required this.portionsShared,
    required this.batchCount,
    required this.activeRescues,
    required this.matchedCount,
    required this.pickupSoonCount,
    required this.pickupSoonMinutes,
    required this.pickupSoonDetail,
    required this.rescuesComplete,
    required this.completionRate,
    required this.activeSurplus,
    this.draftSurplus = const [],
    this.pastSurplus = const [],
    required this.recentActivity,
  });

  final PartnerProfile profile;

  final int portionsShared;
  final int batchCount;
  final int activeRescues;
  final int matchedCount;

  final int pickupSoonCount;

  /// Minutes until the soonest collection, driving both the metric card and
  /// the amber alert banner.
  final int pickupSoonMinutes;

  /// "18 meal boxes awaiting collection."
  final String pickupSoonDetail;

  final int rescuesComplete;

  /// 0-100.
  final int completionRate;

  final List<PartnerSurplus> activeSurplus;

  /// Saved but never published.
  final List<PartnerSurplus> draftSurplus;

  /// Closed batches, collected or expired.
  final List<PartnerSurplus> pastSurplus;

  final List<PartnerActivityRow> recentActivity;

  /// The list behind a given Surplus tab.
  List<PartnerSurplus> surplusFor(PartnerSurplusTab tab) => switch (tab) {
    PartnerSurplusTab.active => activeSurplus,
    PartnerSurplusTab.drafts => draftSurplus,
    PartnerSurplusTab.history => pastSurplus,
  };

  /// "3 batches".
  String get batchLabel => '$batchCount batches';

  /// "1 matched".
  String get matchedLabel => '$matchedCount matched';

  /// "In 12 min".
  String get pickupSoonLabel => 'In $pickupSoonMinutes min';

  /// "Pickup in 12 min".
  String get pickupAlertTitle => 'Pickup in $pickupSoonMinutes min';

  /// "96%".
  String get completionRateLabel => '$completionRate%';

  /// The design greets by time of day.
  String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
