import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets an `autoDispose` provider survive navigation, while still refetching
/// once its value is older than [duration].
///
/// Moving between tabs disposes every provider the outgoing screen was
/// watching, so Home → Explore → Home used to run the nearby query twice
/// within a couple of seconds. A rebuild is not a request for fresher data,
/// and paying a round trip for one is the difference between a tab switch that
/// feels instant and one that shows a spinner.
///
/// Deliberately not a bare `keepAlive()`, which holds the first answer for the
/// life of the app: a listing list that never expires goes on offering food
/// somebody else has already collected. Instead the value is held, and the
/// *next* time something listens the age is checked — if it has gone stale the
/// provider refetches, and the screen shows its ordinary loading state.
///
/// Deliberately not a timer either. A pending timer per provider is real work
/// scheduled on a device that may have navigated away entirely, and it
/// outlives the widget test that created it. Checking the clock on resume
/// costs nothing when nobody is looking.
///
/// Anything that must be current after an action — a claim, a publish — is
/// invalidated explicitly by the code that performed it. That still works:
/// invalidation drops the value regardless of this window.
///
/// Not for data that must be fresh on every read, and not for anything
/// authoritative about rescue state.
void cacheFor(Ref ref, Duration duration) {
  ref.keepAlive();

  // Set when the last listener goes away, so the age measured is "how long
  // since anyone cared", not "how long since it was fetched" — a screen left
  // open is already watching and gets its updates by invalidation.
  DateTime? idleSince;
  var disposed = false;

  ref.onDispose(() => disposed = true);
  ref.onCancel(() => idleSince = DateTime.now());

  ref.onResume(() {
    final since = idleSince;
    idleSince = null;
    if (since == null) return;
    if (DateTime.now().difference(since) <= duration) return;

    // Deferred by a microtask, not a timer: Riverpod forbids touching a Ref
    // from inside a life-cycle callback, and a microtask carries no scheduled
    // work on a device that may have navigated away. The listener that just
    // arrived then sees a normal loading state rather than a stale value
    // presented as current.
    Future.microtask(() {
      if (!disposed) ref.invalidateSelf();
    });
  });
}
