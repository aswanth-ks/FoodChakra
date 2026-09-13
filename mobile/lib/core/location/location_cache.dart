import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'location_providers.dart';

/// Remembers the last real fix across app launches.
///
/// Without this, every cold start begins with no idea where the user is, so
/// Home and Explore both wait on a full permission-plus-GPS round trip before
/// the first request can even be made. A fix from a few minutes ago is a real
/// reading, and for "food near you" it is indistinguishable from a fresh one.
///
/// It is written to encrypted storage rather than plain preferences. Where
/// someone has been is not a credential, but it is not something to leave
/// readable either.
///
/// A stored fix is never treated as current: [read] refuses anything older
/// than [maxAge], so a phone opened in another city does not claim to be where
/// it was last week. Callers still refresh in the background — this only
/// decides what can be shown *first*.
class LocationCache {
  const LocationCache(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'foodloop.location.last_fix';

  /// Encrypted storage crosses a platform channel, and a platform channel can
  /// fail to answer. This sits in front of the nearby query, so a hung read
  /// would hold up the whole of Home — the exact infinite wait this pass is
  /// removing. Not answering quickly is treated as having nothing stored.
  static const Duration _ioTimeout = Duration(seconds: 2);

  /// Past this, a stored fix is discarded rather than shown. Long enough to
  /// cover closing and reopening the app, short enough that it cannot survive
  /// a journey.
  static const Duration maxAge = Duration(hours: 6);

  /// The last fix, or null when there is none, it cannot be read, or it is
  /// too old to stand for "here".
  Future<DeviceLocation?> read() async {
    try {
      final raw = await _storage.read(key: _key).timeout(_ioTimeout);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final latitude = (json['lat'] as num?)?.toDouble();
      final longitude = (json['lng'] as num?)?.toDouble();
      final capturedAt = DateTime.tryParse(json['at'] as String? ?? '');
      if (latitude == null || longitude == null || capturedAt == null) {
        return null;
      }
      if (DateTime.now().difference(capturedAt) > maxAge) return null;

      return DeviceLocation(
        latitude: latitude,
        longitude: longitude,
        capturedAt: capturedAt,
      );
    } catch (_) {
      // A corrupt or unreadable entry is the same as having none. This sits
      // on the launch path, so it must never be the reason the app fails to
      // start.
      return null;
    }
  }

  Future<void> write(DeviceLocation location) async {
    try {
      await _storage
          .write(
            key: _key,
            value: jsonEncode({
              'lat': location.latitude,
              'lng': location.longitude,
              'at': location.capturedAt.toIso8601String(),
            }),
          )
          .timeout(_ioTimeout);
    } catch (_) {
      // Best effort. Failing to remember where we are costs one GPS fix next
      // launch; it is not worth failing anything else over.
    }
  }

  /// Forgotten on sign-out, so one account's whereabouts never carry into the
  /// next session.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key).timeout(_ioTimeout);
    } catch (_) {}
  }
}

final locationCacheProvider = Provider<LocationCache>(
  (ref) => const LocationCache(FlutterSecureStorage()),
);
