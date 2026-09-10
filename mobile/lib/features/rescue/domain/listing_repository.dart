import 'food_listing.dart';

/// Repository contract owned by the domain layer.
///
/// The presentation layer depends on this interface, never the implementation,
/// so screens can be driven by a fake with no HTTP.
abstract interface class ListingRepository {
  /// Claimable surplus near a point, nearest first. Backs Explore.
  Future<List<FoodListing>> nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    List<String> foodTypes,
    String? source,
    int limit,
    int offset,
  });

  /// One listing, for the Food Details screen.
  Future<FoodListing> byId(String id);

  /// The signed-in account's own listings. Backs Activity and Partner Surplus.
  Future<List<FoodListing>> mine({List<String> statuses});

  /// Publishes surplus from the Give flow. Returns the created listing.
  Future<FoodListing> create(NewListing listing);

  /// Withdraws a listing the account owns.
  Future<FoodListing> cancel(String id, {String? reason});
}

/// What the Give flow submits.
///
/// A plain value type rather than the UI's `SurplusDraft`: the draft carries
/// `TimeOfDay`s and a local photo path, which are presentation concerns. The
/// mapping happens once, at the point of publishing.
class NewListing {
  const NewListing({
    required this.foodName,
    required this.foodType,
    required this.quantity,
    required this.unit,
    required this.safetyConfirmed,
    required this.pickupLabel,
    required this.latitude,
    required this.longitude,
    required this.pickupFrom,
    required this.pickupUntil,
    this.source,
    this.preparedWhen,
    this.description,
    this.tags = const [],
    this.weightKg,
    this.pickupLocality,
  });

  final String foodName;

  /// Wire values: `vegetarian`, `vegan`, `non_veg`, `other`.
  final String foodType;
  final int quantity;

  /// Wire values: `meal_boxes`, `servings`, `kilograms`.
  final String unit;
  final bool safetyConfirmed;

  final String pickupLabel;
  final String? pickupLocality;
  final double latitude;
  final double longitude;

  final DateTime pickupFrom;
  final DateTime pickupUntil;

  /// `home` or `event`.
  final String? source;

  /// `just_prepared`, `earlier_today`, `yesterday`, `other`.
  final String? preparedWhen;

  final String? description;
  final List<String> tags;

  /// Optional at creation — the Give UI does not ask for it. Zero-Waste
  /// fallback routing needs it before a listing can be tiered.
  final double? weightKg;
}
