import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/location/location_providers.dart';
import '../features/rescue/presentation/listing_providers.dart';

/// Refreshes what has gone stale when the app comes back to the foreground.
///
/// Returning after hours is the case this exists for. Without it the app woke
/// up holding a location from another day and a listings result from another
/// session, and nothing asked again until the user happened to pull to refresh
/// — or, worse, it woke holding a *failed* location whose error had been
/// cached since, and every screen stayed broken until the app was killed.
///
/// What it deliberately does not do:
///
/// * It does not reload the navigation tree. The shell stays exactly where it
///   was; providers refresh underneath it, so there is no full-screen spinner
///   and no losing your place.
/// * It does not refresh on every resume. A glance at a notification and a
///   return two seconds later is not a reason to spend two round trips, so
///   nothing happens again within [_minimumGap].
/// * It does not touch the session. Auth renews itself on demand through the
///   interceptor, single-flight; prodding it here would be a second path to
///   the same thing and a way to reintroduce a refresh race.
class ResumeRefresher extends ConsumerStatefulWidget {
  const ResumeRefresher({super.key, required this.child});

  final Widget child;

  /// How long the app must have been away before a resume is worth acting on.
  static const Duration minimumAway = Duration(minutes: 2);

  @override
  ConsumerState<ResumeRefresher> createState() => _ResumeRefresherState();
}

class _ResumeRefresherState extends ConsumerState<ResumeRefresher>
    with WidgetsBindingObserver {
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Recorded on the way out rather than measured on the way in, so a
        // brief switch away is told apart from an overnight one.
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _leftAt;
        _leftAt = null;
        if (away == null) return;
        if (DateTime.now().difference(away) < ResumeRefresher.minimumAway) {
          return;
        }
        _refresh();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Drops the two things that genuinely go stale while the app is away.
  ///
  /// One invalidation each, and only these two: the location the user may have
  /// moved away from, and the listings other people may have claimed. Each
  /// screen re-requests once, through the same shared providers, so returning
  /// costs exactly one nearby query however many screens are on the stack.
  void _refresh() {
    final stored = ref.read(deviceLocationProvider);
    final tooOld =
        stored == null ||
        DateTime.now().difference(stored.capturedAt) > _locationStaleAfter;

    if (tooOld) {
      // Forgetting the in-memory fix is what makes the origin resolve again
      // from the remembered fix or the device, rather than handing back
      // yesterday's coordinates.
      ref.read(deviceLocationProvider.notifier).clear();
    }
    ref.invalidate(currentOriginProvider);
    ref.invalidate(nearbyListingsProvider);
  }

  /// Past this the user has plausibly moved somewhere else.
  static const Duration _locationStaleAfter = Duration(minutes: 15);

  @override
  Widget build(BuildContext context) => widget.child;
}
