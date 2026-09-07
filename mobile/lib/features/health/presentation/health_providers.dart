import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/health_repository_impl.dart';
import '../domain/health_repository.dart';
import '../domain/health_status.dart';

/// Binds the repository interface to its implementation.
///
/// Tests override this provider with a fake, which is why the presentation
/// layer only ever references the interface.
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepositoryImpl(ref.watch(dioProvider));
});

/// Async state for the health screen.
///
/// `AsyncValue` gives loading / data / error for free — the screen maps each
/// case onto the shared state widgets.
final healthStatusProvider = FutureProvider.autoDispose<HealthStatus>((ref) {
  return ref.watch(healthRepositoryProvider).fetchHealth();
});
