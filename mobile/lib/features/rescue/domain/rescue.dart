import 'food_listing.dart';

/// One consumer's claim on a listing.
///
/// The backend's canonical lifecycle is authoritative; [stage] is the
/// projection of it that this app's stepper renders, computed server-side so
/// the two clients cannot disagree.
class Rescue {
  const Rescue({
    required this.id,
    required this.reference,
    required this.status,
    required this.isActive,
    required this.listing,
    this.stage,
    this.cancelReason,
    this.handoverCode,
  });

  final String id;

  /// "FL-20481".
  final String reference;

  /// The canonical lifecycle value, e.g. `matched`, `onTheWay`, `cancelled`.
  final String status;

  /// Null once the rescue leaves the stepper (cancelled, and terminal states).
  final RescueStage? stage;

  /// Whether the rescue is still running.
  final bool isActive;

  /// The food being rescued, as the rescue screens render it.
  final FoodListing listing;

  final String? cancelReason;

  /// The six-digit code the rescuer reads out to the food's owner, who enters
  /// it to confirm the handover.
  ///
  /// Set only in the response to marking arrival, and only for the rescuer —
  /// it is null everywhere else, including on later reads of the same rescue.
  final String? handoverCode;
}
