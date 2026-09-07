import '../domain/food_listing.dart';

/// Placeholder listings, verbatim from the Stitch designs.
///
/// PHASE 5: delete this file. The screens take their data through constructor
/// parameters precisely so that swapping these fixtures for a repository is a
/// router-level change, not a screen rewrite.
///
/// The coordinates are placeholders near Karur, Tamil Nadu — the locality the
/// Home design shows — so "Start navigation" opens a real, plausible route.
/// They are not real venues.
class SampleListings {
  const SampleListings._();

  static const FoodListing mealBoxes = FoodListing(
    id: 'meal-boxes',
    title: '25 Meal Boxes',
    category: 'Vegetarian',
    distanceKm: 1.4,
    imageAsset: 'assets/images/food_meal_boxes.jpg',
    urgency: ListingUrgency.expiring,
    timeRemaining: Duration(minutes: 42),
    servings: 25,
    pickupWindow: 'Today, 7:30 PM – 8:30 PM',
    pickupLocation: 'Community Hall',
    pickupLocality: 'Karur, Tamil Nadu',
    latitude: 10.9577,
    longitude: 78.0809,
    sharedBy: 'Community Event Organizer',
    description:
        'Freshly prepared vegetarian meals from today’s community event. '
        'Packed in clean reusable containers and ready for immediate pickup.',
    tags: ['Plant-Based', 'Ready to Eat', 'Reusable Containers'],
    travelEstimate: 'Est. 6 min drive / 18 min walk',
  );

  static const FoodListing bakeryBasket = FoodListing(
    id: 'bakery-basket',
    title: 'Artisanal Bakery Basket',
    category: 'Pastries & Loaves',
    distanceKm: 2.1,
    imageAsset: 'assets/images/food_bakery_basket.jpg',
    urgency: ListingUrgency.expiring,
    timeRemaining: Duration(minutes: 42),
    servings: 12,
    pickupWindow: 'Today, 6:00 PM – 7:00 PM',
    pickupLocation: 'The Daily Loaf',
    pickupLocality: 'Karur, Tamil Nadu',
    latitude: 10.9652,
    longitude: 78.0714,
    sharedBy: 'The Daily Loaf Bakery',
    description:
        'End-of-day sourdough loaves, croissants and pastries from the '
        'bakery counter. Still fresh, boxed and ready to collect.',
    tags: ['Bakery', 'Ready to Eat', 'Same Day'],
    travelEstimate: 'Est. 8 min drive / 26 min walk',
  );

  /// The Home screen's "Nearby opportunities" list. The first card renders as
  /// available, the second as expiring — matching the design.
  static const List<FoodListing> nearby = [
    FoodListing(
      id: 'meal-boxes',
      title: '25 Meal Boxes',
      category: 'Vegetarian',
      distanceKm: 1.4,
      imageAsset: 'assets/images/food_meal_boxes.jpg',
      urgency: ListingUrgency.available,
      servings: 25,
      pickupWindow: 'Today, 7:30 PM – 8:30 PM',
      pickupLocation: 'Community Hall',
      pickupLocality: 'Karur, Tamil Nadu',
      latitude: 10.9577,
      longitude: 78.0809,
      sharedBy: 'Community Event Organizer',
      description:
          'Freshly prepared vegetarian meals from today’s community event. '
          'Packed in clean reusable containers and ready for immediate pickup.',
      tags: ['Plant-Based', 'Ready to Eat', 'Reusable Containers'],
      travelEstimate: 'Est. 6 min drive / 18 min walk',
    ),
    bakeryBasket,
  ];


  static const FoodListing fruitBox = FoodListing(
    id: 'fruit-box',
    title: 'Seasonal Fruit Box',
    category: 'Vegan',
    quantityLabel: 'Sliced melon & berries',
    distanceKm: 0.8,
    imageAsset: 'assets/images/food_fruit_box.jpg',
    urgency: ListingUrgency.critical,
    timeRemaining: Duration(minutes: 9),
    isLive: true,
    servings: 8,
    pickupWindow: 'Today, 6:30 PM – 7:00 PM',
    pickupLocation: 'Fresh Harvest Stall',
    pickupLocality: 'Karur, Tamil Nadu',
    latitude: 10.9612,
    longitude: 78.0755,
    sharedBy: 'Fresh Harvest',
    description:
        'Ready-sliced melon, grapes and berries boxed this morning. Best '
        'eaten today, so it needs collecting soon.',
    tags: ['Vegan', 'Ready to Eat', 'Chilled'],
    travelEstimate: 'Est. 4 min drive / 11 min walk',
  );

  static const FoodListing eventPacks = FoodListing(
    id: 'event-packs',
    title: 'Event Buffet Packs',
    category: 'Vegetarian & Lentils',
    quantityLabel: '30 packs',
    distanceKm: 3.4,
    imageAsset: 'assets/images/food_event_packs.jpg',
    urgency: ListingUrgency.scheduled,
    availableFromLabel: '7:30 PM',
    servings: 30,
    pickupWindow: 'Today, 7:30 PM – 9:00 PM',
    pickupLocation: 'Riverside Function Hall',
    pickupLocality: 'Karur, Tamil Nadu',
    latitude: 10.9498,
    longitude: 78.0921,
    sharedBy: 'Riverside Events',
    description:
        'Untouched buffet portions packed after a community function. '
        'Released for collection once the event closes.',
    tags: ['Vegetarian', 'Ready to Eat', 'Bulk'],
    travelEstimate: 'Est. 11 min drive / 42 min walk',
  );

  /// The Explore screen's result list, in the design's order (sorted by the
  /// design's own ranking, not strictly by distance).
  static const List<FoodListing> explore = [
    FoodListing(
      id: 'meal-boxes',
      title: '25 Meal Boxes',
      category: 'Vegetarian',
      distanceKm: 1.4,
      imageAsset: 'assets/images/food_meal_boxes.jpg',
      urgency: ListingUrgency.expiring,
      timeRemaining: Duration(minutes: 42),
      isLive: true,
      servings: 25,
      pickupWindow: 'Today, 7:30 PM – 8:30 PM',
      pickupLocation: 'Community Hall',
      pickupLocality: 'Karur, Tamil Nadu',
      latitude: 10.9577,
      longitude: 78.0809,
      sharedBy: 'Community Event Organizer',
      description:
          'Freshly prepared vegetarian meals from today’s community event. '
          'Packed in clean reusable containers and ready for immediate pickup.',
      tags: ['Plant-Based', 'Ready to Eat', 'Reusable Containers'],
      travelEstimate: 'Est. 6 min drive / 18 min walk',
    ),
    FoodListing(
      id: 'bakery-basket',
      title: 'Artisanal Bakery Tray',
      category: 'Sourdough & pastries',
      quantityLabel: '18 items',
      distanceKm: 2.1,
      imageAsset: 'assets/images/food_bakery_basket.jpg',
      urgency: ListingUrgency.available,
      servings: 18,
      pickupWindow: 'Today, 6:00 PM – 7:00 PM',
      pickupLocation: 'The Daily Loaf',
      pickupLocality: 'Karur, Tamil Nadu',
      latitude: 10.9652,
      longitude: 78.0714,
      sharedBy: 'The Daily Loaf Bakery',
      description:
          'End-of-day sourdough loaves, croissants and pastries from the '
          'bakery counter. Still fresh, boxed and ready to collect.',
      tags: ['Bakery', 'Ready to Eat', 'Same Day'],
      travelEstimate: 'Est. 8 min drive / 26 min walk',
    ),
    fruitBox,
    eventPacks,
  ];

  /// Lookup used by the `/food/:id` and rescue routes.
  static FoodListing byId(String id) => switch (id) {
    'bakery-basket' => bakeryBasket,
    'fruit-box' => fruitBox,
    'event-packs' => eventPacks,
    _ => mealBoxes,
  };
}
