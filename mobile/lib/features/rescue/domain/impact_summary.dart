/// Whether an impact entry was food the user collected or gave away.
enum ImpactEntryKind { rescued, shared }

/// One completed line on the "Recent activity" list.
class ImpactEntry {
  const ImpactEntry({
    required this.title,
    required this.kind,
    required this.whenLabel,
  });

  /// "25 Meal Boxes".
  final String title;

  final ImpactEntryKind kind;

  /// "Today, 8:05 PM", "Yesterday", "Aug 10".
  final String whenLabel;

  /// "Rescued" / "Shared".
  String get kindLabel => switch (kind) {
    ImpactEntryKind.rescued => 'Rescued',
    ImpactEntryKind.shared => 'Shared',
  };

  /// "Completed" / "Handed over". The design appends a tick to both.
  String get outcomeLabel => switch (kind) {
    ImpactEntryKind.rescued => 'Completed',
    ImpactEntryKind.shared => 'Handed over',
  };
}

/// The headline figures on the My Impact screen.
///
/// Deliberately plain counts, no scores or streaks — the design is explicit
/// that this is a factual tally rather than a gamified one. Phase 5 computes
/// these from the rescue history instead of the fixtures.
class ImpactSummary {
  const ImpactSummary({
    required this.mealBoxes,
    required this.rescues,
    required this.servings,
    required this.shares,
    this.rangeLabel = '30 days',
    this.lastUpdatedLabel = 'Last updated today',
  });

  /// The hero number: total meal boxes rescued.
  final int mealBoxes;

  final int rescues;
  final int servings;
  final int shares;

  /// The time filter's current selection.
  final String rangeLabel;

  final String lastUpdatedLabel;

  /// "Across 4 successful rescues".
  String get rescuesLabel =>
      'Across $rescues successful ${rescues == 1 ? 'rescue' : 'rescues'}';
}
