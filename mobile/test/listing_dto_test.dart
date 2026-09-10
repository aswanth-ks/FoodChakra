import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/features/rescue/data/listing_dto.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';

void main() {
  Map<String, dynamic> json({
    String urgency = 'available',
    double? distanceKm = 1.4,
  }) {
    final now = DateTime.now();
    return {
      'id': '68c0',
      'reference': 'FL-20481',
      'title': '25 Meal Boxes',
      'food_name': 'Vegetable biryani',
      'food_type': 'vegetarian',
      'category': 'Vegetarian',
      'quantity': 25,
      'unit': 'meal_boxes',
      'quantity_label': 'Approx. 25 servings',
      'servings': 25,
      'status': 'published',
      'urgency': urgency,
      'pickup_from': now.toUtc().toIso8601String(),
      'pickup_until': now.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      'expires_at': now.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      'pickup_location': {
        'label': 'Community Hall',
        'locality': 'Karur, Tamil Nadu',
        'latitude': 10.9577,
        'longitude': 78.0809,
      },
      'distance_km': distanceKm,
      'shared_by': 'Community Event Organizer',
      'shared_by_verified': true,
      'source_kind': 'consumer',
      'is_live': false,
      'is_available': true,
      'created_at': now.toUtc().toIso8601String(),
      'description': 'Freshly prepared vegetarian meals.',
      'tags': ['Plant-Based'],
      'prepared_note': 'Prepared earlier today',
      'prepared_when': 'earlier_today',
    };
  }

  test('maps the API shape onto the screens domain entity', () {
    final listing = FoodListingDto.fromJson(json()).toDomain();

    expect(listing.id, '68c0');
    expect(listing.title, '25 Meal Boxes');
    expect(listing.category, 'Vegetarian');
    expect(listing.distanceKm, 1.4);
    expect(listing.pickupLocation, 'Community Hall');
    expect(listing.pickupLocality, 'Karur, Tamil Nadu');
    expect(listing.latitude, 10.9577);
    expect(listing.longitude, 78.0809);
    expect(listing.sharedBy, 'Community Event Organizer');
    expect(listing.tags, ['Plant-Based']);
    // Coordinates present means "Start navigation" opens a real route.
    expect(listing.destinationLabel, 'Community Hall, Karur, Tamil Nadu');
  });

  test('maps every urgency the server can send', () {
    for (final (wire, expected) in [
      ('available', ListingUrgency.available),
      ('expiring', ListingUrgency.expiring),
      ('critical', ListingUrgency.critical),
      ('scheduled', ListingUrgency.scheduled),
    ]) {
      expect(
        FoodListingDto.fromJson(json(urgency: wire)).toDomain().urgency,
        expected,
      );
    }
  });

  test('an unknown urgency falls back to available rather than throwing', () {
    final listing = FoodListingDto.fromJson(json(urgency: 'wat')).toDomain();
    expect(listing.urgency, ListingUrgency.available);
  });

  test('builds a readable pickup window', () {
    final listing = FoodListingDto.fromJson(json()).toDomain();
    expect(listing.pickupWindow, contains('Today, '));
    expect(listing.pickupWindow, contains(' – '));
  });

  test('a missing distance does not crash the card', () {
    // /listings/{id} and /listings/mine return no distance.
    final listing = FoodListingDto.fromJson(json(distanceKm: null)).toDomain();
    expect(listing.distanceKm, 0);
  });

  test('an empty payload degrades instead of throwing', () {
    final listing = FoodListingDto.fromJson(const {}).toDomain();
    expect(listing.id, '');
    expect(listing.tags, isEmpty);
  });
}
