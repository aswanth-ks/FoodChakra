import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/rescue_repository_impl.dart';
import '../domain/rescue.dart';
import '../domain/rescue_repository.dart';

/// Binds the repository interface to its implementation.
final rescueRepositoryProvider = Provider<RescueRepository>(
  (ref) => RescueRepositoryImpl(ref.watch(dioProvider)),
);

/// One rescue, for the Rescuer Found and Active Rescue screens.
final rescueDetailProvider = FutureProvider.autoDispose.family<Rescue, String>((
  ref,
  id,
) {
  return ref.watch(rescueRepositoryProvider).byId(id);
});

/// The rescue holding one of the caller's own listings — the owner's entry
/// into the handover.
final rescueForListingProvider = FutureProvider.autoDispose
    .family<Rescue, String>((ref, listingId) {
      return ref.watch(rescueRepositoryProvider).activeForListing(listingId);
    });

/// The signed-in consumer's rescues. Backs the Activity screen.
final myRescuesProvider = FutureProvider.autoDispose<List<Rescue>>((ref) {
  return ref.watch(rescueRepositoryProvider).mine();
});
