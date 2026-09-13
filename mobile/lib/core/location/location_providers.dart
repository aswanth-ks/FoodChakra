import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_cache.dart';
import 'location_service.dart';

/// Raised when a real position cannot be obtained.
///
/// A distinct type so screens can tell "we do not know where you are" apart
/// from a network or server problem, and say something useful about it.
class LocationUnavailable implements Exception {
  const LocationUnavailable();

  @override
  String toString() => 'LocationUnavailable';
}

/// Binds the location service so tests can substitute a fake.
///
/// Production code resolves the real `LocationService`, which is the only
/// thing in the app that talks to geolocator.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

/// A real fix taken from the device, as plain coordinates.
///
/// Deliberately not geolocator's `Position`: only latitude and longitude ever
/// leave this layer, so nothing downstream depends on the plugin's types.
class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  /// Built from a real platform reading. There is no other constructor, and
  /// no default or placeholder coordinate anywhere in this file — an unknown
  /// location is represented by null, never by a stand-in pair like a city
  /// centre, which would silently show the wrong food to the wrong person.
  factory DeviceLocation.fromPosition(Position position) => DeviceLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    capturedAt: position.timestamp,
  );

  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  /// Roughly how far this point is from [other], in metres.
  ///
  /// An equirectangular approximation, which is accurate to well under a metre
  /// at the scale that matters here and avoids a trigonometric haversine for a
  /// question only ever asked as "did we move?".
  double metresFrom(DeviceLocation other) {
    const metresPerDegree = 111320.0;
    final dLat = (latitude - other.latitude) * metresPerDegree;
    // Longitude degrees shrink towards the poles. Taken at the mean latitude
    // of the two points so the answer does not depend on which one is asked.
    final meanLatitude = (latitude + other.latitude) / 2;
    final dLng =
        (longitude - other.longitude) *
        metresPerDegree *
        math.cos(meanLatitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.capturedAt == capturedAt;

  @override
  int get hashCode => Object.hash(latitude, longitude, capturedAt);

  @override
  String toString() =>
      'DeviceLocation($latitude, $longitude, at $capturedAt)';
}

/// The last real location obtained from the device, or null when there is
/// none.
///
/// This is the single place the app remembers where the user is. Nearby-food
/// requests read it from here rather than each calling the platform again.
/// Null means "not known yet" and must stay that way until a real fix
/// arrives: callers are expected to ask for location rather than assume one.
class DeviceLocationController extends Notifier<DeviceLocation?> {
  @override
  DeviceLocation? build() => null;

  /// Records a fix taken from the device.
  ///
  /// [remember] is false only when the fix *came* from the cache, so reading
  /// it back does not rewrite it with the same values and a newer timestamp —
  /// that would let a stale fix renew itself indefinitely and outlive the age
  /// limit it is supposed to obey.
  void set(DeviceLocation location, {bool remember = true}) {
    state = location;
    if (remember) ref.read(locationCacheProvider).write(location);
  }

  /// Records a fix straight from a platform reading.
  void setFromPosition(Position position) =>
      set(DeviceLocation.fromPosition(position));

  /// Forgets the fix — on sign-out, so one account's whereabouts are never
  /// carried into the next session. Clears the persisted copy too.
  void clear() {
    state = null;
    ref.read(locationCacheProvider).clear();
  }
}

final deviceLocationProvider =
    NotifierProvider<DeviceLocationController, DeviceLocation?>(
      DeviceLocationController.new,
    );
