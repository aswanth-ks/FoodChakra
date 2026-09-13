import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/core/location/location_service.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/presentation/explore_screen.dart';
import 'package:foodloop/features/rescue/presentation/explore_view.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:foodloop/core/location/location_cache.dart';

import 'support/fake_location_cache.dart';

FoodListing listing({
  String id = 'l1',
  String title = '25 Meal Boxes',
  ListingUrgency urgency = ListingUrgency.available,
  String? locality = 'Karur, Tamil Nadu',
}) => FoodListing(
  id: id,
  title: title,
  category: 'Vegetarian',
  distanceKm: 1.4,
  imageAsset: 'assets/images/food_meal_boxes.jpg',
  urgency: urgency,
  servings: 25,
  pickupWindow: 'Today, 7:30 PM – 8:30 PM',
  pickupLocation: 'Community Hall',
  pickupLocality: locality,
  sharedBy: 'Asha Rao',
  description: 'Freshly prepared.',
  tags: const [],
);

/// Records what actually reached the API, so a chip can be proved to change
/// the query rather than only its own colour.
class RecordingListings implements ListingRepository {
  RecordingListings({this.results = const []});

  List<FoodListing> results;
  Failure? failWith;
  Completer<void>? gate;

  final List<
    ({double latitude, double longitude, List<String> foodTypes, String? source})
  >
  queries = [];

  @override
  Future<List<FoodListing>> nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    List<String> foodTypes = const [],
    String? source,
    int limit = 20,
    int offset = 0,
  }) async {
    queries.add((
      latitude: latitude,
      longitude: longitude,
      foodTypes: foodTypes,
      source: source,
    ));
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
    return results;
  }

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// Counts platform calls, to prove the stored fix is reused.
class CountingLocation implements LocationService {
  int requestCalls = 0;

  @override
  Future<LocationReadiness> readiness() async => LocationReadiness.ready;

  @override
  Future<LocationResult> requestLocation() async {
    requestCalls++;
    return LocationResult(
      LocationOutcome.granted,
      position: Position(
        latitude: 9.5,
        longitude: 78.5,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
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

  late RecordingListings listings;
  late CountingLocation location;

  setUp(() {
    listings = RecordingListings();
    location = CountingLocation();
  });

  Future<ProviderContainer> show(
    WidgetTester tester, {
    DeviceLocation? storedFix,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        listingRepositoryProvider.overrideWithValue(listings),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);

    if (storedFix != null) {
      container.read(deviceLocationProvider.notifier).set(storedFix);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ExploreView()),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Selects a chip, scrolling the horizontal chip row to it first.
  ///
  /// The row is a lazy horizontal ListView: chips past either edge are not
  /// built until scrolled into view, and a chip that has been scrolled past
  /// can sit to the *left* of the viewport. The row is rewound to the start
  /// before searching rightwards, and the scroll is allowed to come to rest
  /// before tapping — tapping a chip still in motion lands on empty space.
  Future<void> tapFilter(WidgetTester tester, String label) async {
    Finder? builtChip() {
      for (final chip in ExploreScreen.filters) {
        final finder = find.text(chip);
        if (finder.evaluate().isNotEmpty) return finder.first;
      }
      return null;
    }

    Future<void> nudge(double dx) async {
      final handle = builtChip();
      if (handle == null) return;
      await tester.drag(handle, Offset(dx, 0));
      await settle(tester);
    }

    // Rewind to the first chip, wherever the row was left.
    for (var i = 0; i < 6; i++) {
      await nudge(200);
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      if (find.text(label).evaluate().isNotEmpty) break;
      await nudge(-140);
    }

    expect(find.text(label), findsWidgets, reason: 'could not reach $label');

    // Built is not the same as tappable: a chip scrolled only partly in sits
    // clipped at the right edge and fails hit testing. Keep going until its
    // centre is clear of that edge.
    for (var attempt = 0; attempt < 6; attempt++) {
      final centre = tester.getCenter(find.text(label).first);
      if (centre.dx < 320) break;
      await nudge(-100);
    }

    await tester.tap(find.text(label).first);
    await settle(tester);
  }

  group('result states', () {
    testWidgets('the chrome and filters stay usable while loading', (
      tester,
    ) async {
      listings.gate = Completer<void>();

      await show(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The screen itself is up, not a bare full-page spinner.
      expect(find.byType(ExploreScreen), findsOneWidget);
      // The chip row is lazy, so only the leading chips are built; their
      // presence is what proves the chrome survived the loading state.
      expect(find.text('Nearby'), findsWidgets);
      expect(find.text('Ready now'), findsWidgets);
      expect(find.bySemanticsLabel('Loading nearby food'), findsWidgets);

      listings.gate!.complete();
      await settle(tester);
    });

    testWidgets('a successful empty result gets the empty state', (
      tester,
    ) async {
      listings.results = const [];

      await show(tester);
      await settle(tester);

      expect(find.text('Nothing to rescue right now'), findsOneWidget);
      expect(
        find.textContaining('No surplus food is available nearby yet'),
        findsOneWidget,
      );
      // An empty success is never dressed up as a failure.
      expect(find.text("Couldn't load nearby food"), findsNothing);
      expect(find.bySemanticsLabel('Loading nearby food'), findsNothing);
    });

    testWidgets('real listings render', (tester) async {
      listings.results = [
        listing(),
        listing(id: 'l2', title: '10 Sandwiches'),
      ];

      await show(tester);
      await settle(tester);

      expect(find.text('25 Meal Boxes'), findsWidgets);
      expect(find.text('10 Sandwiches'), findsWidgets);
      expect(find.text('Nothing to rescue right now'), findsNothing);
    });

    testWidgets('a failure shows the error state, never the empty state', (
      tester,
    ) async {
      listings
        ..results = [listing()]
        ..failWith = const NetworkFailure();

      await show(tester);
      await settle(tester);

      expect(find.text("Couldn't load nearby food"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // These three are the whole point of separating the states.
      expect(find.text('Nothing to rescue right now'), findsNothing);
      expect(find.text('25 Meal Boxes'), findsNothing);
      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('Try again re-queries the backend', (tester) async {
      listings
        ..results = [listing()]
        ..failWith = const NetworkFailure();

      await show(tester);
      await settle(tester);
      final before = listings.queries.length;

      listings.failWith = null;
      await tester.tap(find.text('Try again'));
      await settle(tester);

      expect(listings.queries.length, greaterThan(before));
      expect(find.text('25 Meal Boxes'), findsWidgets);
    });

    testWidgets('the default chip reuses Home query, no second request', (
      tester,
    ) async {
      listings.results = [listing()];

      await show(tester);
      await settle(tester);

      // Explore opens on "Nearby", which asks the server exactly what Home
      // asks: nearest first, no food type, no source. One query, not two.
      expect(listings.queries.length, 1);
      expect(listings.queries.single.foodTypes, isEmpty);
      expect(listings.queries.single.source, isNull);
    });

    testWidgets('filters remain reachable from an empty result', (
      tester,
    ) async {
      listings.results = const [];

      await show(tester);
      await settle(tester);
      expect(find.text('Nothing to rescue right now'), findsOneWidget);

      // The bug this guards: the empty view used to replace the chip row, so
      // a filter matching nothing left no way back to one that matched.
      listings.results = [listing()];
      await tapFilter(tester, 'Vegan');

      expect(listings.queries.last.foodTypes, ['vegan']);
      expect(find.text('25 Meal Boxes'), findsWidgets);
    });
  });

  group('location', () {
    testWidgets('a stored fix is used and the platform is not asked', (
      tester,
    ) async {
      listings.results = [listing()];

      await show(
        tester,
        storedFix: DeviceLocation(
          latitude: 11.25,
          longitude: 77.5,
          capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      await settle(tester);

      expect(location.requestCalls, 0);
      expect(listings.queries.single.latitude, 11.25);
      expect(listings.queries.single.longitude, 77.5);
    });

    testWidgets('with no stored fix the real device location is used once', (
      tester,
    ) async {
      listings.results = [listing()];

      await show(tester);
      await settle(tester);

      expect(location.requestCalls, 1);
      // The coordinates that reached the API are the ones the device gave —
      // nothing hardcoded, and no stand-in origin.
      expect(listings.queries.single.latitude, 9.5);
      expect(listings.queries.single.longitude, 78.5);

      await settle(tester);
      expect(location.requestCalls, 1, reason: 'rebuilds must not re-ask GPS');
    });
  });

  group('filters reach the query', () {
    // Vegetarian and Vegan are covered at provider level in
    // backend_backed_screens_test, and the Vegan chip is exercised through
    // the UI by "filters remain reachable from an empty result" above. A
    // third widget-level pass over the same ground only re-fought the lazy
    // chip row, so it is not duplicated here.

    testWidgets('Event food narrows by source', (tester) async {
      listings.results = [listing()];
      await show(tester);
      await settle(tester);

      await tapFilter(tester, 'Event food');
      expect(listings.queries.last.source, 'event');
    });

    testWidgets('Nearby asks for everything', (tester) async {
      listings.results = [listing()];
      await show(tester);
      await settle(tester);

      // The default chip's own query, made on first load: no food type and no
      // source. Read from the first query rather than the last, because
      // returning to a chip does not re-ask — see the test below.
      expect(listings.queries.first.foodTypes, isEmpty);
      expect(listings.queries.first.source, isNull);
    });

    testWidgets('returning to a filter reuses its result, no second query', (
      tester,
    ) async {
      listings.results = [listing()];
      await show(tester);
      await settle(tester);

      await tapFilter(tester, 'Vegan');
      await settle(tester);
      final afterVegan = listings.queries.length;
      expect(listings.queries.last.foodTypes, ['vegan']);

      await tapFilter(tester, 'Nearby');
      await settle(tester);

      // Flipping back is navigation, not a request for fresher data. The
      // result fetched moments ago is reused instead of paying another round
      // trip for an answer nobody expects to have changed.
      expect(listings.queries.length, afterVegan);
    });

    testWidgets('Expiring soon keeps only what the server called urgent', (
      tester,
    ) async {
      listings.results = [
        listing(id: 'a', title: 'Calm Curry'),
        listing(id: 'b', title: 'Urgent Rice', urgency: ListingUrgency.expiring),
      ];
      await show(tester);
      await settle(tester);

      await tapFilter(tester, 'Expiring soon');

      // The urgency is the server's own value, not recomputed here.
      expect(find.text('Urgent Rice'), findsWidgets);
      expect(find.text('Calm Curry'), findsNothing);
    });

    testWidgets('Ready now drops listings that have not opened yet', (
      tester,
    ) async {
      listings.results = [
        listing(id: 'a', title: 'Open Now'),
        listing(
          id: 'b',
          title: 'Later Today',
          urgency: ListingUrgency.scheduled,
        ),
      ];
      await show(tester);
      await settle(tester);

      await tapFilter(tester, 'Ready now');

      expect(find.text('Open Now'), findsWidgets);
      expect(find.text('Later Today'), findsNothing);
    });

    testWidgets('a filter that matches nothing says so, and offers a way out', (
      tester,
    ) async {
      listings.results = [listing()];
      await show(tester);
      await settle(tester);

      listings.results = const [];
      await tapFilter(tester, 'Vegan');

      expect(find.text('Nothing to rescue right now'), findsOneWidget);
      expect(
        find.textContaining('No surplus food matches "Vegan" nearby'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the real listing id is what opens Food Details', (tester) async {
    listings.results = [listing(id: '68c1f0a2e4b09a77c3d51234')];
    FoodListing? opened;

    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        listingRepositoryProvider.overrideWithValue(listings),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ExploreView(onOpenListing: (l) => opened = l),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('25 Meal Boxes').first);
    await tester.pump();

    // The server's own document id, carried through untouched.
    expect(opened?.id, '68c1f0a2e4b09a77c3d51234');
  });
}
