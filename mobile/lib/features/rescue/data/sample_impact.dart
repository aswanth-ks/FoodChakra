import '../domain/impact_summary.dart';

/// Placeholder impact figures, verbatim from the Stitch design.
///
/// PHASE 5: delete this file. The screen takes its data through constructor
/// parameters so swapping these for a repository is a router-level change.
class SampleImpact {
  const SampleImpact._();

  static const ImpactSummary summary = ImpactSummary(
    mealBoxes: 48,
    rescues: 4,
    servings: 72,
    shares: 3,
  );

  static const List<ImpactEntry> recent = [
    ImpactEntry(
      title: '25 Meal Boxes',
      kind: ImpactEntryKind.rescued,
      whenLabel: 'Today, 8:05 PM',
    ),
    ImpactEntry(
      title: '15 Meal Boxes',
      kind: ImpactEntryKind.shared,
      whenLabel: 'Yesterday',
    ),
    ImpactEntry(
      title: '8 Meal Boxes',
      kind: ImpactEntryKind.rescued,
      whenLabel: 'Aug 10',
    ),
  ];

  /// The time filter's options. Only the label is used until Phase 5.
  static const List<String> ranges = ['7 days', '30 days', '12 months', 'All time'];
}
