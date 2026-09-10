import 'rescue.dart';

/// Repository contract owned by the domain layer.
abstract interface class RescueRepository {
  /// Tap-to-claim. Throws a `ConflictFailure`-shaped failure when the listing
  /// was claimed by someone else first.
  Future<Rescue> claim(String listingId);

  Future<Rescue> byId(String rescueId);

  /// The signed-in consumer's rescues. Backs the Activity screen.
  Future<List<Rescue>> mine({bool activeOnly});

  /// Marks travel started when the rescuer opens navigation.
  Future<Rescue> startTravel(String rescueId);

  /// The rescue currently holding one of the caller's own listings.
  ///
  /// How an owner finds the rescue they are being asked to confirm — a rescue
  /// is otherwise readable only by its rescuer.
  Future<Rescue> activeForListing(String listingId);

  /// Marks arrival at the pickup point. The returned rescue carries the
  /// handover code for the rescuer to read out.
  Future<Rescue> markArrived(String rescueId);

  /// The food owner confirms the handover with the rescuer's code.
  ///
  /// The rescuer cannot call this — the backend refuses it. Someone must
  /// confirm the food actually changed hands.
  Future<Rescue> verifyHandover(String rescueId, {required String code});

  /// The rescuer confirms they have the food. Requires a confirmed handover,
  /// and completes the rescue.
  Future<Rescue> markCollected(String rescueId);

  Future<Rescue> cancel(String rescueId, {String? reason});
}
