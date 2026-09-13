/// A surplus-food listing a consumer can rescue.
///
/// A plain value type with no JSON of its own: `FoodListingDto` in `data/`
/// owns the wire format and maps onto this, which is why the screens needed no
/// changes when the fixtures were replaced by the real listings API.
enum ListingUrgency {
  /// Inside its pickup window with time to spare — shown in brand green.
  available,

  /// Close to the end of its window — shown in restrained amber.
  expiring,

  /// Minutes from expiry — the only place the designs use red.
  critical,

  /// Not collectable yet; opens later today — shown in neutral grey.
  scheduled,
}

/// Where a confirmed rescue has got to. Drives the Active Rescue stepper.
enum RescueStage { confirmed, preparing, ready, pickup, collected }

class FoodListing {
  const FoodListing({
    required this.id,
    required this.title,
    required this.category,
    required this.distanceKm,
    required this.imageAsset,
    required this.urgency,
    required this.servings,
    required this.pickupWindow,
    required this.pickupLocation,
    required this.sharedBy,
    required this.description,
    required this.tags,
    this.latitude,
    this.longitude,
    this.pickupLocality,
    this.quantityLabel,
    this.availableFromLabel,
    this.isLive = false,
    this.timeRemaining,
    this.status,
    this.quantityCount,
    this.unit,
    this.preparedNote = 'Prepared today',
    this.sharedByVerified = true,
    this.travelEstimate,
  });

  final String id;

  /// "25 Meal Boxes".
  final String title;

  /// "Vegetarian", "Pastries & Loaves" — the one-line food kind.
  final String category;

  final double distanceKm;

  /// Bundled asset path. Remote photography arrives with the Phase 5 API.
  final String imageAsset;

  final ListingUrgency urgency;
  final int servings;

  /// "Today, 7:30 PM – 8:30 PM".
  final String pickupWindow;

  /// "Community Hall".
  final String pickupLocation;

  /// The town the pickup point sits in, e.g. "Karur, Tamil Nadu". Used to
  /// disambiguate [pickupLocation] when no coordinates are known.
  final String? pickupLocality;

  /// Pickup coordinates. Null until the listings API supplies them, in which
  /// case maps fall back to searching [destinationLabel] by name.
  final double? latitude;
  final double? longitude;

  /// "Community Event Organizer".
  final String sharedBy;
  final bool sharedByVerified;

  final String description;
  final List<String> tags;

  /// How the amount reads on a card: "Approx. 25 servings", "18 items".
  /// Falls back to the servings count.
  final String? quantityLabel;

  /// When [urgency] is [ListingUrgency.scheduled], the time it opens —
  /// "7:30 PM". Ignored otherwise.
  final String? availableFromLabel;

  /// Whether the listing is streaming live updates, which puts the "LIVE"
  /// badge on its photo.
  final bool isLive;

  /// Time left in the pickup window. Only set for [ListingUrgency.expiring].
  final Duration? timeRemaining;

  /// The server's canonical lifecycle value (`published`, `matched`, …).
  ///
  /// Null for a listing that did not come from the API. The client never
  /// derives it — it decides only what to show, never what state something is
  /// in.
  final String? status;

  /// The counted amount and its unit — named `quantityCount` because
  /// [quantity] is already the display label the cards render.
  ///
  /// The counted amount and its unit (`meal_boxes`, `servings`, `kilograms`),
  /// as published. Impact totals are summed from these rather than parsed back
  /// out of a display label.
  final int? quantityCount;
  final String? unit;

  /// True once a rescuer has claimed this listing.
  bool get isClaimed => status == 'matched';

  final String preparedNote;

  /// "Est. 6 min drive / 18 min walk".
  final String? travelEstimate;

  /// "1.4 km away".
  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km away';

  /// "Vegetarian · 1.4 km away".
  String get subtitle => '$category · $distanceLabel';

  /// What to hand a maps app when [latitude]/[longitude] are unknown.
  String get destinationLabel => pickupLocality == null
      ? pickupLocation
      : '$pickupLocation, $pickupLocality';

  /// "Approx. 25 servings" unless the listing overrides it.
  String get quantity => quantityLabel ?? 'Approx. $servings servings';

  /// The Explore card's second line: "Vegetarian · Approx. 25 servings".
  String get exploreSubtitle => '$category · $quantity';

  /// "Ready for pickup", or "Available at 7:30 PM" while scheduled.
  String get readinessLabel =>
      urgency == ListingUrgency.scheduled && availableFromLabel != null
      ? 'Available at $availableFromLabel'
      : 'Ready for pickup';

  /// The urgency chip's text, derived rather than stored so it can never
  /// disagree with [urgency] and [timeRemaining].
  String get urgencyLabel => switch (urgency) {
    ListingUrgency.expiring ||
    ListingUrgency.critical => 'Expiring in ${timeRemaining?.inMinutes ?? 0} min',
    ListingUrgency.available => 'Available today',
    ListingUrgency.scheduled => 'Pickup today',
  };

  /// "1.4 km" — the compact form the Explore card's corner chip uses.
  String get distanceChipLabel => '${distanceKm.toStringAsFixed(1)} km';

  /// "42 min remaining", or null when the listing is not expiring.
  String? get remainingLabel {
    final d = timeRemaining;
    if (d == null) return null;
    if (d.inHours >= 1) return '${d.inHours} hr remaining';
    return '${d.inMinutes} min remaining';
  }

  /// The deadline half of [pickupWindow], e.g. "8:30 PM".
  String get pickupDeadline {
    final parts = pickupWindow.split('–');
    return parts.length == 2 ? parts.last.trim() : pickupWindow;
  }
}
