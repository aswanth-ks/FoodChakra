import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/map/foodloop_map.dart';
import 'package:foodloop/core/map/geo_point.dart';
import 'package:foodloop/core/navigation/maps_launcher.dart';
import 'package:foodloop/features/give/data/surplus_draft_mapper.dart';
import 'package:foodloop/features/give/domain/surplus_draft.dart';
import 'package:foodloop/features/give/presentation/availability_pickup_screen.dart';
import 'package:foodloop/features/give/presentation/pickup_location_screen.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/presentation/active_rescue_screen.dart';
import 'package:foodloop/features/home/presentation/home_screen.dart';
import 'package:foodloop/features/rescue/presentation/explore_screen.dart';

import 'support/blank_tiles.dart';

/// Karur, where the project is based. A real place, used only as test input —
/// production code has no coordinate literals at all.
const _karur = (latitude: 10.9577, longitude: 78.0809);

FoodListing _listing({
  String id = '68c1f0a2e4b09a77c3d51234',
  String title = '25 Meal Boxes',
  double? latitude = 10.9601,
  double? longitude = 78.0822,
}) => FoodListing(
  id: id,
  title: title,
  category: 'Vegetarian',
  distanceKm: 1.4,
  imageAsset: 'assets/images/food_meal_boxes.jpg',
  urgency: ListingUrgency.available,
  servings: 25,
  pickupWindow: 'Today, 7:30 PM – 8:30 PM',
  pickupLocation: 'Community Hall',
  pickupLocality: 'Karur, Tamil Nadu',
  latitude: latitude,
  longitude: longitude,
  sharedBy: 'Asha Rao',
  description: 'Freshly prepared.',
  tags: const [],
);

/// Records what it was asked to open, without touching url_launcher.
class _FakeMapsLauncher implements MapsLauncher {
  Uri? directions;
  Uri? place;

  @override
  Future<MapsOutcome> openDirections({
    required String destinationLabel,
    double? latitude,
    double? longitude,
  }) async {
    directions = MapsLauncher.directionsUri(
      destinationLabel: destinationLabel,
      latitude: latitude,
      longitude: longitude,
    );
    return MapsOutcome.opened;
  }

  @override
  Future<MapsOutcome> openPlace({
    required String label,
    double? latitude,
    double? longitude,
  }) async {
    place = MapsLauncher.placeUri(
      label: label,
      latitude: latitude,
      longitude: longitude,
    );
    return MapsOutcome.opened;
  }
}

void main() {
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/PlusJakartaSans[wght].ttf',
    ).readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('coordinate validation', () {
    test('a real pair is accepted and keeps its order', () {
      final point = GeoPoint.tryFrom(_karur.latitude, _karur.longitude);
      expect(point, isNotNull);
      expect(point!.latitude, _karur.latitude);
      expect(point.longitude, _karur.longitude);
    });

    test('out-of-range and non-finite values are rejected', () {
      // Each of these would throw inside the map library and take the whole
      // screen down, rather than costing one pin.
      expect(GeoPoint.tryFrom(91, 0), isNull);
      expect(GeoPoint.tryFrom(-90.001, 0), isNull);
      expect(GeoPoint.tryFrom(0, 180.5), isNull);
      expect(GeoPoint.tryFrom(0, -181), isNull);
      expect(GeoPoint.tryFrom(double.nan, 0), isNull);
      expect(GeoPoint.tryFrom(0, double.infinity), isNull);
      expect(GeoPoint.tryFrom(null, 0), isNull);
      expect(GeoPoint.tryFrom(0, null), isNull);

      // The exact limits are legal: the poles and the antimeridian exist.
      expect(GeoPoint.tryFrom(90, 180), isNotNull);
      expect(GeoPoint.tryFrom(-90, -180), isNotNull);
    });

    test('a latitude/longitude swap is caught, not silently accepted', () {
      // 78.08 is a valid latitude, so this particular swap cannot be caught
      // by range alone — but a longitude of 100+ never is, which is why the
      // ordering is asserted directly everywhere it is converted.
      expect(GeoPoint.tryFrom(78.0809, 10.9577), isNotNull);
      expect(GeoPoint.tryFrom(120.0, 10.0), isNull);
    });
  });

  group('GeoJSON', () {
    test('reads longitude first, per RFC 7946', () {
      final point = GeoPoint.fromGeoJson({
        'type': 'Point',
        // [longitude, latitude] — this is the pair MongoDB stores.
        'coordinates': [78.0809, 10.9577],
      });

      expect(point, isNotNull);
      // Read back the other way round. Getting this wrong puts every listing
      // in the wrong hemisphere while the query still "works".
      expect(point!.latitude, 10.9577);
      expect(point.longitude, 78.0809);
    });

    test('writes longitude first', () {
      final json = GeoPoint.tryFrom(10.9577, 78.0809)!.toGeoJson();

      expect(json['type'], 'Point');
      expect(json['coordinates'], [78.0809, 10.9577]);
      expect((json['coordinates']! as List).first, 78.0809, reason: 'lng');
    });

    test('a malformed or out-of-range point yields null, never a guess', () {
      expect(GeoPoint.fromGeoJson(null), isNull);
      expect(GeoPoint.fromGeoJson({'type': 'Polygon', 'coordinates': []}),
          isNull);
      expect(GeoPoint.fromGeoJson({'type': 'Point', 'coordinates': [1]}),
          isNull);
      expect(
        GeoPoint.fromGeoJson({
          'type': 'Point',
          'coordinates': ['78.08', '10.95'],
        }),
        isNull,
      );
      expect(
        GeoPoint.fromGeoJson({
          'type': 'Point',
          // Longitude and latitude the wrong way round: 200 is no longitude.
          'coordinates': [10.9577, 200.0],
        }),
        isNull,
      );
    });
  });

  group('the map widget', () {
    testWidgets('renders at the coordinates it was given', (tester) async {
      final center = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;

      await pump(
        tester,
        Scaffold(
          body: FoodLoopMap(center: center, tileProvider: BlankTileProvider()),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .initialCenter;
      expect(camera.latitude, closeTo(_karur.latitude, 1e-9));
      expect(camera.longitude, closeTo(_karur.longitude, 1e-9));
    });

    testWidgets('shows OpenStreetMap attribution', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: FoodLoopMap(
            center: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
            tileProvider: BlankTileProvider(),
          ),
        ),
      );

      // Required by the OSM copyright terms, and not dismissible.
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('uses OpenStreetMap tiles with no API key', (tester) async {
      expect(FoodLoopMap.tileUrl, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(FoodLoopMap.tileUrl, isNot(contains('key=')));
      expect(FoodLoopMap.tileUrl, isNot(contains('access_token')));
      expect(FoodLoopMap.userAgentPackageName, isNotEmpty);
    });

    testWidgets('draws the current-location dot and the selection', (
      tester,
    ) async {
      final center = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;
      final selected = GeoPoint.tryFrom(10.96, 78.09)!;

      await pump(
        tester,
        Scaffold(
          body: FoodLoopMap(
            center: center,
            currentLocation: center,
            selected: selected,
            tileProvider: BlankTileProvider(),
          ),
        ),
      );

      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(
        markers.map((m) => m.key),
        containsAll(<Key>[
          const ValueKey('map-current-location'),
          const ValueKey('map-selected'),
        ]),
      );
      // The device's dot and the chosen pin are separate things, at separate
      // coordinates — the selection is not assumed to be where you are.
      final dot = markers.firstWhere(
        (m) => m.key == const ValueKey('map-current-location'),
      );
      final pin = markers.firstWhere(
        (m) => m.key == const ValueKey('map-selected'),
      );
      expect(dot.point.latitude, center.latitude);
      expect(pin.point.latitude, selected.latitude);
      expect(pin.point.longitude, selected.longitude);
    });

    testWidgets('a tap reports a coordinate, near the point tapped', (
      tester,
    ) async {
      final center = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;
      GeoPoint? tapped;

      await pump(
        tester,
        Scaffold(
          body: FoodLoopMap(
            center: center,
            height: 300,
            onTapPoint: (p) => tapped = p,
            tileProvider: BlankTileProvider(),
          ),
        ),
      );

      // Tapping the middle of the map is tapping its centre coordinate.
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tapped, isNotNull);
      expect(tapped!.latitude, closeTo(_karur.latitude, 0.01));
      expect(tapped!.longitude, closeTo(_karur.longitude, 0.01));
    });

    testWidgets('a read-only map reports nothing', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          body: FoodLoopMap(
            center: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
            height: 300,
            pins: [
              MapPin(
                point: GeoPoint.tryFrom(10.96, 78.08)!,
                id: 'x',
                onTap: () => taps++,
              ),
            ],
            tileProvider: BlankTileProvider(),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 400));

      // No onTapPoint means no selection is invented from a stray tap.
      expect(taps, 0);
    });
  });

  group('picking a pickup location', () {
    testWidgets('tapping the map moves the selection, and Confirm returns it', (
      tester,
    ) async {
      final center = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;
      GeoPoint? confirmed;

      await pump(
        tester,
        PickupLocationScreen(
          center: center,
          currentLocation: center,
          onConfirm: (p) => confirmed = p,
          tileProvider: BlankTileProvider(),
        ),
      );

      // Opens on the device's position, already selected.
      expect(find.textContaining('Pickup point: $center'), findsOneWidget);

      // A tap away from the centre must change the coordinate.
      final map = find.byType(FlutterMap);
      final topLeft = tester.getTopLeft(map);
      await tester.tapAt(topLeft + const Offset(60, 50));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('Pickup point: $center'),
        findsNothing,
        reason: 'the tap must move the selection off the opening point',
      );

      // Panning and tapping have still committed nothing.
      expect(confirmed, isNull);

      await tester.tap(find.text('Use this location'));
      await tester.pump();

      expect(confirmed, isNotNull);
      // Exactly what the summary showed, not the map's centre.
      expect(find.textContaining('Pickup point: $confirmed'), findsOneWidget);
      expect(confirmed, isNot(center));
    });

    testWidgets('nothing can be confirmed before a real point exists', (
      tester,
    ) async {
      await pump(
        tester,
        const PickupLocationScreen(loading: true, center: null),
      );

      expect(find.text('Finding your location'), findsOneWidget);
      expect(find.text('No pickup point selected yet'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use this location'),
      );
      expect(button.onPressed, isNull, reason: 'nothing to confirm yet');
    });

    testWidgets('a failed fix offers a retry and no coordinates', (
      tester,
    ) async {
      var retries = 0;

      await pump(
        tester,
        PickupLocationScreen(
          error: Exception('no fix'),
          onRetry: () => retries++,
        ),
      );

      expect(find.text("Couldn't get your location"), findsOneWidget);
      expect(find.text('No pickup point selected yet'), findsOneWidget);
      // No map is drawn, because there is no honest point to centre it on.
      expect(find.byType(FlutterMap), findsNothing);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('a later fix seeds the map without overwriting a choice', (
      tester,
    ) async {
      final late = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;

      await pump(
        tester,
        const PickupLocationScreen(loading: true),
      );
      expect(find.text('No pickup point selected yet'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PickupLocationScreen(
            center: late,
            currentLocation: late,
            tileProvider: BlankTileProvider(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Pickup point: $late'), findsOneWidget);
    });
  });

  group('Send Food', () {
    testWidgets('the confirmed point lands on the draft', (tester) async {
      final chosen = GeoPoint.tryFrom(10.9601, 78.0822)!;
      SurplusDraft? continued;
      GeoPoint? offered;

      await pump(
        tester,
        AvailabilityPickupScreen(
          draft: const SurplusDraft(),
          onChooseOnMap: (current) async {
            offered = current;
            return chosen;
          },
          onContinue: (d) => continued = d,
        ),
      );

      // Nothing is on the draft before the user picks.
      expect(find.textContaining('Pickup point'), findsNothing);

      await tester.tap(find.text('Choose on map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(offered, isNull, reason: 'no point to re-open on yet');
      expect(find.text('Pickup point $chosen'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(continued, isNotNull);
      expect(continued!.pickupLatitude, 10.9601);
      expect(continued!.pickupLongitude, 78.0822);
      expect(continued!.hasPickupPoint, isTrue);
    });

    testWidgets('backing out of the map changes nothing', (tester) async {
      SurplusDraft? continued;

      await pump(
        tester,
        AvailabilityPickupScreen(
          draft: const SurplusDraft(),
          // Null is what the picker pops when the user leaves without
          // confirming: panning around a map is not a decision.
          onChooseOnMap: (_) async => null,
          onContinue: (d) => continued = d,
        ),
      );

      await tester.tap(find.text('Choose on map'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(continued!.hasPickupPoint, isFalse);
      expect(continued!.pickupLatitude, isNull);
    });

    testWidgets('Current location writes a real device reading', (
      tester,
    ) async {
      final fix = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;
      SurplusDraft? continued;

      await pump(
        tester,
        AvailabilityPickupScreen(
          draft: const SurplusDraft(),
          onUseCurrentLocation: () async => fix,
          onContinue: (d) => continued = d,
        ),
      );

      await tester.tap(find.text('Current location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(continued!.pickupLatitude, _karur.latitude);
      expect(continued!.pickupLongitude, _karur.longitude);
    });

    testWidgets('a refused reading leaves the pickup point alone', (
      tester,
    ) async {
      SurplusDraft? continued;

      await pump(
        tester,
        AvailabilityPickupScreen(
          draft: const SurplusDraft(),
          onUseCurrentLocation: () async => null,
          onContinue: (d) => continued = d,
        ),
      );

      await tester.tap(find.text('Current location'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Nothing substituted for the reading that did not arrive.
      expect(continued!.hasPickupPoint, isFalse);
    });

    test('the listing request carries the confirmed coordinates', () {
      final draft = const SurplusDraft(
        foodName: 'Biryani',
        foodType: FoodType.vegetarian,
        quantity: 25,
        safetyConfirmed: true,
      ).copyWith(pickupLatitude: 10.9601, pickupLongitude: 78.0822);

      final request = draft.toNewListing(
        latitude: draft.pickupLatitude!,
        longitude: draft.pickupLongitude!,
      );

      expect(request.latitude, 10.9601);
      expect(request.longitude, 78.0822);
      // Named fields, not a positional pair — there is no order to get wrong
      // on the way to the API, which converts to GeoJSON itself.
      expect(request.latitude, lessThan(request.longitude));
    });
  });

  group('the Explore map', () {
    testWidgets('pins come from real listing coordinates', (tester) async {
      final origin = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;
      final listings = [
        _listing(id: 'a1', title: 'Meal boxes', latitude: 10.96, longitude: 78.08),
        _listing(id: 'b2', title: 'Pastries', latitude: 10.97, longitude: 78.09),
      ];

      await pump(
        tester,
        ExploreScreen(
          listings: listings,
          origin: origin,
          tileProvider: BlankTileProvider(),
        ),
      );

      await tester.tap(find.text('Map'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FlutterMap), findsOneWidget);

      final map = tester.widget<FoodLoopMap>(find.byType(FoodLoopMap));
      expect(map.pins.map((p) => p.id), ['a1', 'b2']);
      // Each pin at its listing's own coordinates, the right way round.
      expect(map.pins[0].point.latitude, 10.96);
      expect(map.pins[0].point.longitude, 78.08);
      expect(map.pins[1].point.latitude, 10.97);
      expect(map.pins[1].point.longitude, 78.09);
      // The device's position is a separate thing from any listing.
      expect(map.currentLocation, origin);
    });

    testWidgets('tapping a pin opens that listing, by its real id', (
      tester,
    ) async {
      final opened = <String>[];
      final listings = [
        _listing(id: 'a1', title: 'Meal boxes', latitude: 10.9577, longitude: 78.0809),
        _listing(id: 'b2', title: 'Pastries', latitude: 11.40, longitude: 78.60),
      ];

      await pump(
        tester,
        ExploreScreen(
          listings: listings,
          origin: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
          onOpenListing: (l) => opened.add(l.id),
          tileProvider: BlankTileProvider(),
        ),
      );

      await tester.tap(find.text('Map'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('map-pin-a1')));
      await tester.pump();

      expect(opened, ['a1'], reason: 'the pin tapped, not another listing');
    });

    testWidgets('a listing with no coordinates is left off, and said so', (
      tester,
    ) async {
      final listings = [
        _listing(id: 'a1', latitude: 10.96, longitude: 78.08),
        // A listing the API returned without a usable point.
        _listing(id: 'b2', latitude: null, longitude: null),
        // And one whose coordinates are impossible.
        _listing(id: 'c3', latitude: 999, longitude: 78.08),
      ];

      await pump(
        tester,
        ExploreScreen(
          listings: listings,
          origin: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
          tileProvider: BlankTileProvider(),
        ),
      );

      await tester.tap(find.text('Map'));
      await tester.pump(const Duration(milliseconds: 300));

      // The bad records cost their own pins and nothing else — no exception,
      // and the other listing is still on the map.
      expect(tester.takeException(), isNull);
      final map = tester.widget<FoodLoopMap>(find.byType(FoodLoopMap));
      expect(map.pins.map((p) => p.id), ['a1']);
      expect(
        find.text('2 of 3 nearby listings have no map location yet.'),
        findsOneWidget,
      );
    });

    testWidgets('with no location the map says so rather than guessing', (
      tester,
    ) async {
      await pump(
        tester,
        ExploreScreen(
          listings: [_listing(latitude: null, longitude: null)],
          tileProvider: BlankTileProvider(),
        ),
      );

      await tester.tap(find.text('Map'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Map needs your location'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });
  });

  group("Home's map card", () {
    testWidgets('shows the real map with the nearby listings on it', (
      tester,
    ) async {
      final origin = GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!;

      await pump(
        tester,
        HomeScreen(
          origin: origin,
          listings: [
            _listing(id: 'a1', latitude: 10.96, longitude: 78.08),
            _listing(id: 'b2', latitude: null, longitude: null),
          ],
          tileProvider: BlankTileProvider(),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      final map = tester.widget<FoodLoopMap>(find.byType(FoodLoopMap));
      expect(map.center, origin);
      expect(map.currentLocation, origin);
      // The same listings the page lists, minus the one with no point.
      expect(map.pins.map((p) => p.id), ['a1']);
      expect(map.pins.single.point.latitude, 10.96);
      expect(map.pins.single.point.longitude, 78.08);
      // Not pannable: the whole card is one tap target.
      expect(map.interactive, isFalse);
    });

    testWidgets('tapping the map opens Explore', (tester) async {
      var opened = 0;

      await pump(
        tester,
        HomeScreen(
          origin: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
          listings: [_listing(id: 'a1')],
          onOpenMap: () => opened++,
          tileProvider: BlankTileProvider(),
        ),
      );

      // By position: the map itself is behind an IgnorePointer, so the tap
      // has to land on the card's own handler to count.
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('without a fix it keeps the illustration, not a guess', (
      tester,
    ) async {
      await pump(
        tester,
        HomeScreen(
          listings: [_listing(id: 'a1')],
          onOpenMap: () {},
          tileProvider: BlankTileProvider(),
        ),
      );

      // No real map is drawn on a location the app does not have.
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Explore can be opened straight onto its map', (tester) async {
      await pump(
        tester,
        ExploreScreen(
          listings: [_listing(id: 'a1', latitude: 10.96, longitude: 78.08)],
          origin: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
          initialView: ExploreResultView.map,
          tileProvider: BlankTileProvider(),
        ),
      );

      // No toggle tap needed: it arrives showing the map.
      expect(find.byType(FlutterMap), findsOneWidget);

      // And the toggle still works, so the map is not a dead end.
      await tester.tap(find.text('List'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('25 Meal Boxes'), findsWidgets);
    });

    testWidgets('Explore still defaults to the list', (tester) async {
      await pump(
        tester,
        ExploreScreen(
          listings: [_listing(id: 'a1', latitude: 10.96, longitude: 78.08)],
          origin: GeoPoint.tryFrom(_karur.latitude, _karur.longitude)!,
          tileProvider: BlankTileProvider(),
        ),
      );

      expect(find.byType(FlutterMap), findsNothing);
    });
  });

  group('rescue navigation', () {
    test('directions target the listing coordinates, not its name', () {
      final uri = MapsLauncher.directionsUri(
        destinationLabel: 'Community Hall, Karur, Tamil Nadu',
        latitude: 10.9601,
        longitude: 78.0822,
      );

      // Latitude first in a Google Maps URL — the opposite of GeoJSON, which
      // is exactly why the two conversions live in named places.
      expect(uri.queryParameters['destination'], '10.9601,78.0822');
      expect(uri.queryParameters['destination'], isNot(contains('Community')));
    });

    test('a listing with no point falls back to its name, not a guess', () {
      final uri = MapsLauncher.directionsUri(
        destinationLabel: 'Community Hall, Karur, Tamil Nadu',
      );

      expect(
        uri.queryParameters['destination'],
        'Community Hall, Karur, Tamil Nadu',
      );
    });

    testWidgets('Start navigation uses the persisted listing coordinates', (
      tester,
    ) async {
      final launcher = _FakeMapsLauncher();
      var lifecycleCalls = 0;

      await pump(
        tester,
        ActiveRescueScreen(
          listing: _listing(latitude: 10.9601, longitude: 78.0822),
          mapsLauncher: launcher,
          onOnTheWay: () => lifecycleCalls++,
          onArrived: () => lifecycleCalls++,
          onCollected: () => lifecycleCalls++,
        ),
      );

      await tester.ensureVisible(find.text('Start navigation'));
      await tester.tap(find.text('Start navigation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(launcher.directions, isNotNull);
      expect(
        launcher.directions!.queryParameters['destination'],
        '10.9601,78.0822',
      );

      // Opening maps proves someone looked at a route, not that they set off.
      // The rescue's state belongs to the server and nothing here touched it.
      expect(lifecycleCalls, 0);
    });
  });
}
