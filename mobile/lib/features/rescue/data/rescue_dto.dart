import '../domain/food_listing.dart';
import '../domain/rescue.dart';
import 'listing_dto.dart';

/// Wire format for `/api/v1/rescues`.
///
/// The rescue carries a snapshot of its listing, so the rescue screens render
/// from one response rather than two round trips.
class RescueDto {
  const RescueDto(this.json);

  final Map<String, dynamic> json;

  factory RescueDto.fromJson(Map<String, dynamic> json) => RescueDto(json);

  Rescue toDomain() {
    final listing =
        (json['listing'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Rescue(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      status: json['status'] as String? ?? 'matched',
      stage: _stage(json['stage'] as String?),
      isActive: json['is_active'] as bool? ?? false,
      cancelReason: json['cancel_reason'] as String?,
      handoverCode: json['handover_code'] as String?,
      // The snapshot omits the fields only Explore needs, so the shared DTO
      // fills its own defaults for them.
      listing: FoodListingDto.fromJson({
        ...listing,
        'distance_km': json['distance_km'],
      }).toDomain(),
    );
  }

  /// The server projects the canonical status onto the stepper; an unknown
  /// value simply leaves the stepper unset rather than guessing a position.
  static RescueStage? _stage(String? value) => switch (value) {
    'confirmed' => RescueStage.confirmed,
    'preparing' => RescueStage.preparing,
    'ready' => RescueStage.ready,
    'pickup' => RescueStage.pickup,
    'collected' => RescueStage.collected,
    _ => null,
  };
}
