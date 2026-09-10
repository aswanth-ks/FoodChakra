import '../domain/food_listing.dart';

/// Wire format for a listing from `/api/v1/listings`.
///
/// DTOs own JSON parsing and convert to a domain entity, so `FoodListing`
/// stays free of the API's shape — which is why the Explore and Details
/// screens needed no changes when the fixtures were replaced.
class FoodListingDto {
  const FoodListingDto(this.json);

  final Map<String, dynamic> json;

  factory FoodListingDto.fromJson(Map<String, dynamic> json) =>
      FoodListingDto(json);

  FoodListing toDomain() {
    final location =
        (json['pickup_location'] as Map?)?.cast<String, dynamic>() ?? const {};
    final from = _parseDate(json['pickup_from']);
    final until = _parseDate(json['pickup_until']);

    return FoodListing(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      // Remote photography is not uploaded yet; the bundled asset keeps the
      // cards looking right until it is.
      imageAsset: _imageFor(json['food_type'] as String?),
      urgency: _urgency(json['urgency'] as String?),
      servings: (json['servings'] as num?)?.toInt() ?? 0,
      pickupWindow: _windowLabel(from, until),
      pickupLocation: location['label'] as String? ?? 'Pickup point',
      pickupLocality: location['locality'] as String?,
      latitude: (location['latitude'] as num?)?.toDouble(),
      longitude: (location['longitude'] as num?)?.toDouble(),
      sharedBy: json['shared_by'] as String? ?? 'FoodLoop member',
      sharedByVerified: json['shared_by_verified'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      quantityLabel: json['quantity_label'] as String?,
      availableFromLabel: from == null ? null : _timeLabel(from),
      isLive: json['is_live'] as bool? ?? false,
      timeRemaining: _remaining(until),
      status: json['status'] as String?,
      quantityCount: (json['quantity'] as num?)?.toInt(),
      unit: json['unit'] as String?,
      preparedNote: json['prepared_note'] as String? ?? 'Prepared today',
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  /// Only set while the window is closing, matching `FoodListing`'s contract.
  static Duration? _remaining(DateTime? until) {
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static ListingUrgency _urgency(String? value) => switch (value) {
    'critical' => ListingUrgency.critical,
    'expiring' => ListingUrgency.expiring,
    'scheduled' => ListingUrgency.scheduled,
    _ => ListingUrgency.available,
  };

  /// "Today, 7:30 PM – 8:30 PM".
  static String _windowLabel(DateTime? from, DateTime? until) {
    if (from == null || until == null) return 'Pickup window';
    return '${_dayLabel(from)}, ${_timeLabel(from)} – ${_timeLabel(until)}';
  }

  static String _dayLabel(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final difference = day.difference(today).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    return '${when.day} ${_months[when.month - 1]}';
  }

  static String _timeLabel(DateTime when) {
    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${when.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _imageFor(String? foodType) => switch (foodType) {
    'vegan' || 'vegetarian' => 'assets/images/food_meal_boxes.jpg',
    _ => 'assets/images/food_meal_boxes.jpg',
  };

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
