import '../domain/activity_item.dart';

/// Placeholder activity, verbatim from the Stitch design.
///
/// PHASE 5: delete this file. The screen takes its data through constructor
/// parameters so swapping these for a repository is a router-level change.
class SampleActivity {
  const SampleActivity._();

  static const List<ActivityItem> active = [
    ActivityItem(
      id: 'meal-boxes',
      kind: ActivityKind.rescue,
      status: ActivityStatus.readyForPickup,
      title: '25 Meal Boxes',
      categoryLabel: 'Vegetarian',
      imageAsset: 'assets/images/food_meal_boxes.jpg',
      timeRemaining: Duration(minutes: 42),
      locationLine: 'Community Hall · 1.4 km away',
      detailLine: 'Today · By 8:30 PM',
    ),
    ActivityItem(
      id: 'bakery-trays',
      kind: ActivityKind.share,
      status: ActivityStatus.lookingForRescuer,
      title: '15 Bakery Trays',
      categoryLabel: 'Bakery & Pastries',
      imageAsset: 'assets/images/food_bakery_basket.jpg',
      timeRemaining: Duration(minutes: 58),
      note: 'FoodLoop is matching with nearby community rescuers.',
      detailLine: 'Pickup at Community Hall',
    ),
  ];

  static const String historyHeading = 'Previous 7 Days';

  static const String historySummary =
      'You successfully completed 4 rescues and 2 food shares this month.';

  static const List<ActivityHistoryEntry> history = [
    ActivityHistoryEntry(
      title: '12kg Organic Produce Box',
      subtitle: 'Completed Yesterday · Central Market',
      outcomeLabel: 'Collected',
    ),
    ActivityHistoryEntry(
      title: '8 Soup Portions',
      subtitle: 'Completed Oct 14 · Green Fork Cafe',
      outcomeLabel: 'Shared',
    ),
  ];
}
