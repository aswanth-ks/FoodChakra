/// A validated geographic point.
///
/// Every coordinate that reaches the map passes through here. The map library
/// throws on an out-of-range latitude, so a single bad record from the API
/// would otherwise take down the whole Explore map rather than just omitting
/// one pin — [tryFrom] is what keeps one bad listing from costing the user all
/// the others.
///
/// This type is also the only place that knows GeoJSON is longitude-first.
/// Getting that order wrong does not fail loudly: it silently relocates every
/// listing, and the query still returns results, just the wrong ones.
class GeoPoint {
  const GeoPoint._(this.latitude, this.longitude);

  /// Builds a point, or null when either value is outside its real range or
  /// is not a finite number. NaN and infinity are rejected explicitly: both
  /// slip past a naive range comparison, since every comparison with NaN is
  /// false.
  static GeoPoint? tryFrom(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    return GeoPoint._(latitude, longitude);
  }

  /// Reads a GeoJSON `Point` — `{"type":"Point","coordinates":[lng,lat]}`.
  ///
  /// Position 0 is longitude and position 1 is latitude, per RFC 7946. The
  /// FoodLoop API returns listings with the pair already split into named
  /// `latitude`/`longitude` fields, so this exists for anything reading a
  /// stored document directly, and to state the ordering in one testable
  /// place.
  static GeoPoint? fromGeoJson(Map<String, dynamic>? geoJson) {
    if (geoJson == null) return null;
    if (geoJson['type'] != 'Point') return null;
    final coordinates = geoJson['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (longitude is! num || latitude is! num) return null;
    return tryFrom(latitude.toDouble(), longitude.toDouble());
  }

  final double latitude;
  final double longitude;

  /// GeoJSON for this point, longitude first.
  Map<String, dynamic> toGeoJson() => {
    'type': 'Point',
    'coordinates': [longitude, latitude],
  };

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  /// Rounded to about 100 m. Used for display only — never for the values
  /// sent to the API, which keep full precision.
  @override
  String toString() =>
      '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
}
