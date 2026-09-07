/// Whether the user is collecting food or giving it away.
enum ActivityKind { rescue, share }

/// The live state an in-flight activity is in.
enum ActivityStatus {
  /// The food is waiting to be collected by the user.
  readyForPickup,

  /// The user's own surplus is still being matched to a rescuer.
  lookingForRescuer,
}

/// One in-flight entry on the Activity screen's "Active" tab.
///
/// Deliberately separate from `FoodListing`: a listing is something on offer,
/// whereas this is the user's own commitment to it. Phase 5 replaces the
/// fixtures with a repository read.
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    required this.categoryLabel,
    required this.imageAsset,
    required this.detailLine,
    this.timeRemaining,
    this.locationLine,
    this.note,
  });

  final String id;
  final ActivityKind kind;
  final ActivityStatus status;

  /// "25 Meal Boxes".
  final String title;

  /// The small chip above the title: "Vegetarian", "Bakery & Pastries".
  final String categoryLabel;

  final String imageAsset;

  /// The footer's left-hand line: "Today · By 8:30 PM".
  final String detailLine;

  final Duration? timeRemaining;

  /// "Community Hall · 1.4 km away". Shown for rescues.
  final String? locationLine;

  /// Replaces [locationLine] for shares that are still matching.
  final String? note;

  /// "Rescue · Vegetarian" / "Food shared · Bakery & Pastries".
  String get kindLabel => switch (kind) {
    ActivityKind.rescue => 'Rescue · $categoryLabel',
    ActivityKind.share => 'Food shared · $categoryLabel',
  };

  /// "READY FOR PICKUP" / "LOOKING FOR A RESCUER".
  String get statusLabel => switch (status) {
    ActivityStatus.readyForPickup => 'READY FOR PICKUP',
    ActivityStatus.lookingForRescuer => 'LOOKING FOR A RESCUER',
  };

  /// "42 min remaining", or null when nothing is counting down.
  String? get remainingLabel {
    final d = timeRemaining;
    if (d == null) return null;
    if (d.inHours >= 1) return '${d.inHours} hr remaining';
    return '${d.inMinutes} min remaining';
  }

  /// The footer button's text.
  String get actionLabel => switch (status) {
    ActivityStatus.readyForPickup => 'View rescue',
    ActivityStatus.lookingForRescuer => 'Matching status',
  };
}

/// A completed entry on the "History" tab.
class ActivityHistoryEntry {
  const ActivityHistoryEntry({
    required this.title,
    required this.subtitle,
    required this.outcomeLabel,
  });

  final String title;

  /// "Completed Yesterday · Central Market".
  final String subtitle;

  /// "Collected" / "Shared".
  final String outcomeLabel;
}
