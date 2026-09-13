import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// A tile provider that serves one transparent pixel from memory.
///
/// Widget tests must never reach the network — the test HTTP client answers
/// every request with a 400, which turns each tile into a thrown image error.
/// This keeps the map's geometry, markers and attribution exactly as they are
/// in production while the tiles themselves are inert.
///
/// Test-only. Production always uses the real OpenStreetMap tiles.
class BlankTileProvider extends TileProvider {
  BlankTileProvider() : super();

  static final Uint8List _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}
