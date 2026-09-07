import 'package:url_launcher/url_launcher.dart';

/// Result of handing a destination off to the device's maps app.
enum MapsOutcome {
  /// A maps app (or the browser) accepted the request.
  opened,

  /// Nothing on the device can handle the link — no maps app, no browser.
  noHandler,

  /// The platform call itself failed. Most commonly no url_launcher channel
  /// is available (widget tests, an unsupported platform). Callers surface
  /// this the same way as [noHandler] rather than crashing.
  failed,
}

/// Opens an external maps app for directions or to show a place.
///
/// This is the ONLY place in the app that imports `url_launcher`. Screens
/// depend on this service, never the plugin directly, so the real platform
/// call can be swapped for a fake in tests.
///
/// Universal Google Maps HTTPS links are used rather than the Android-only
/// `google.navigation:` scheme: they open the Maps app when it is installed
/// and fall back to the browser when it is not, on both platforms.
class MapsLauncher {
  const MapsLauncher();

  /// Turn-by-turn directions to a destination.
  ///
  /// [latitude]/[longitude] are used when known; otherwise Maps searches for
  /// [destinationLabel], which is why the label should be specific enough to
  /// find (a place name plus its locality).
  Future<MapsOutcome> openDirections({
    required String destinationLabel,
    double? latitude,
    double? longitude,
  }) => _launch(
    directionsUri(
      destinationLabel: destinationLabel,
      latitude: latitude,
      longitude: longitude,
    ),
  );

  /// Shows the destination on a map without starting navigation.
  Future<MapsOutcome> openPlace({
    required String label,
    double? latitude,
    double? longitude,
  }) => _launch(
    placeUri(label: label, latitude: latitude, longitude: longitude),
  );

  /// Built separately from [openDirections] so the URL shape can be unit
  /// tested without a platform channel.
  static Uri directionsUri({
    required String destinationLabel,
    double? latitude,
    double? longitude,
  }) => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': _target(destinationLabel, latitude, longitude),
    'travelmode': 'driving',
  });

  static Uri placeUri({
    required String label,
    double? latitude,
    double? longitude,
  }) => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': _target(label, latitude, longitude),
  });

  /// Coordinates win when present — a name alone can resolve to the wrong
  /// place. `Uri.https` encodes the value, so it is passed through raw here.
  static String _target(String label, double? latitude, double? longitude) =>
      (latitude != null && longitude != null)
      ? '$latitude,$longitude'
      : label;

  Future<MapsOutcome> _launch(Uri uri) async {
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return opened ? MapsOutcome.opened : MapsOutcome.noHandler;
    } catch (_) {
      // Covers MissingPluginException and anything else unexpected.
      return MapsOutcome.failed;
    }
  }
}
