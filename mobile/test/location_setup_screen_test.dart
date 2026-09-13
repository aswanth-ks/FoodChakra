import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/location/location_providers.dart';
import 'package:foodloop/core/location/location_service.dart';
import 'package:foodloop/core/map/foodloop_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:foodloop/features/onboarding/presentation/location_setup_screen.dart';

import 'support/blank_tiles.dart';

/// Stands in for the real geolocator call so tests never touch a platform
/// channel and can control the outcome.
///
/// These fixtures exist only here. Production code has no equivalent: it
/// always goes through the real [LocationService] to the device.
class _FakeLocationService implements LocationService {
  _FakeLocationService(
    this.result, {
    this.readinessResult = LocationReadiness.needsSetup,
  });

  final LocationResult result;
  final LocationReadiness readinessResult;

  bool called = false;
  bool openedAppSettings = false;
  bool openedLocationSettings = false;

  /// Lets a test observe the loading state before the result resolves,
  /// rather than racing a Future that completes within the same microtask.
  final _completer = Completer<void>();

  @override
  Future<LocationResult> requestLocation() async {
    called = true;
    await _completer.future;
    return result;
  }

  @override
  Future<LocationReadiness> readiness() async => readinessResult;

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedLocationSettings = true;
    return true;
  }

  void resolve() => _completer.complete();
}

Position _position({double latitude = 12.9, double longitude = 77.6}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// A service that answers "cannot say" without touching a platform channel.
///
/// The layout tests below are about the screen, not about geolocator. Left
/// with the real service they reach for a method channel that never answers in
/// a test binding, and the bounded calls inside it then leave their timers
/// pending at teardown.
class _InertLocationService implements LocationService {
  const _InertLocationService();

  @override
  Future<LocationReadiness> readiness() async => LocationReadiness.unknown;

  @override
  Future<LocationResult> requestLocation() async =>
      const LocationResult(LocationOutcome.unavailable);

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}

Widget _wrap(Widget c) => MaterialApp(theme: AppTheme.light, home: c);

/// Drives one Enable-location attempt to completion.
Future<void> _tapEnable(WidgetTester tester, _FakeLocationService fake) async {
  await tester.tap(find.text('Enable location'));
  await tester.pump();
  fake.resolve();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('renders the Stitch copy and map markers', (tester) async {
    await tester.pumpWidget(_wrap(const LocationSetupScreen(locationService: _InertLocationService())));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Find food worth\nrescuing near you'), findsOneWidget);
    expect(find.text('Enable location'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    for (final d in ['400m', '650m', '800m']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(
      find.text('Your location is used only to power nearby rescue features.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enable location shows the real map before continuing', (
    tester,
  ) async {
    final fake = _FakeLocationService(
      LocationResult(LocationOutcome.granted, position: _position()),
    );
    LocationOutcome? seen;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(
          locationService: fake,
          onContinue: (o) => seen = o,
          tileProvider: BlankTileProvider(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Enable location'));
    await tester.pump(); // enter the loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fake.resolve();
    // Not pumpAndSettle: the radar pulse loops forever, so this only
    // advances far enough for the resolved Future and the map to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(fake.called, isTrue);
    // The map now stands between the fix and leaving the screen, so the user
    // sees where they are before anything acts on it.
    expect(find.byType(FoodLoopMap), findsOneWidget);
    expect(find.text('Location set (12.900, 77.600).'), findsOneWidget);
    expect(seen, isNull, reason: 'not left the screen yet');

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(seen, LocationOutcome.granted);
  });

  testWidgets('the map centres on the real fix, not a default', (tester) async {
    final fake = _FakeLocationService(
      LocationResult(
        LocationOutcome.granted,
        position: _position(latitude: 51.5072, longitude: -0.1276),
      ),
    );

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(
          locationService: fake,
          tileProvider: BlankTileProvider(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapEnable(tester, fake);

    final map = tester.widget<FoodLoopMap>(find.byType(FoodLoopMap));
    expect(map.center.latitude, 51.5072);
    expect(map.center.longitude, -0.1276);
    // The device's own position is marked as such.
    expect(map.currentLocation, map.center);
  });

  testWidgets('the real coordinates reach application state', (tester) async {
    final fake = _FakeLocationService(
      LocationResult(
        LocationOutcome.granted,
        position: _position(latitude: 51.5072, longitude: -0.1276),
      ),
    );
    Position? captured;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(
          locationService: fake,
          onLocationObtained: (p) => captured = p,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapEnable(tester, fake);

    expect(captured, isNotNull);
    final stored = DeviceLocation.fromPosition(captured!);
    expect(stored.latitude, 51.5072);
    expect(stored.longitude, -0.1276);
  });

  testWidgets('permission denied keeps the user here with a retry', (
    tester,
  ) async {
    final fake = _FakeLocationService(
      const LocationResult(LocationOutcome.denied),
    );
    LocationOutcome? seen;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(locationService: fake, onContinue: (o) => seen = o),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapEnable(tester, fake);

    // The whole point: a refusal must not be reported as success.
    expect(seen, isNull);
    expect(
      find.text('FoodLoop needs your location to find surplus food near you.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('permanently denied offers Open settings', (tester) async {
    final fake = _FakeLocationService(
      const LocationResult(LocationOutcome.deniedForever),
    );
    LocationOutcome? seen;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(locationService: fake, onContinue: (o) => seen = o),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapEnable(tester, fake);

    expect(seen, isNull);
    expect(find.text('Open settings'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(fake.openedAppSettings, isTrue);
  });

  testWidgets('location services off asks the user to turn Location on', (
    tester,
  ) async {
    final fake = _FakeLocationService(
      const LocationResult(LocationOutcome.serviceDisabled),
    );
    LocationOutcome? seen;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(locationService: fake, onContinue: (o) => seen = o),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapEnable(tester, fake);

    expect(seen, isNull);
    expect(find.text('Turn on Location to continue.'), findsOneWidget);

    await tester.tap(find.text('Open location settings'));
    await tester.pump();
    expect(fake.openedLocationSettings, isTrue);
  });

  testWidgets('a failed fix shows an error and stays put', (tester) async {
    final fake = _FakeLocationService(
      const LocationResult(LocationOutcome.unavailable),
    );
    LocationOutcome? seen;
    Position? captured;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(
          locationService: fake,
          onContinue: (o) => seen = o,
          onLocationObtained: (p) => captured = p,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapEnable(tester, fake);

    expect(seen, isNull);
    // No stand-in coordinate is invented when the fix fails.
    expect(captured, isNull);
    expect(
      find.text('Could not get your location. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('an existing grant continues without prompting again', (
    tester,
  ) async {
    final fake = _FakeLocationService(
      LocationResult(
        LocationOutcome.granted,
        position: _position(latitude: 1.5, longitude: 2.5),
      ),
      readinessResult: LocationReadiness.ready,
    );
    LocationOutcome? seen;
    Position? captured;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(
          locationService: fake,
          onContinue: (o) => seen = o,
          onLocationObtained: (p) => captured = p,
        ),
      ),
    );
    await tester.pump();
    fake.resolve();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Nothing was tapped: the screen took the fix it was already entitled to.
    expect(seen, LocationOutcome.granted);
    expect(captured?.latitude, 1.5);
  });

  testWidgets('Skip and Not now continue without requesting location', (
    tester,
  ) async {
    for (final label in ['Skip', 'Not now']) {
      final fake = _FakeLocationService(
        const LocationResult(LocationOutcome.granted),
      );
      LocationOutcome? seen;
      await tester.pumpWidget(
        _wrap(
          LocationSetupScreen(
            locationService: fake,
            onContinue: (o) => seen = o,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(label));
      await tester.pump();

      expect(seen, LocationOutcome.denied, reason: 'via $label');
      expect(fake.called, isFalse, reason: '$label must not request location');
    }
  });

  testWidgets('reduced motion does not run the radar loop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: LocationSetupScreen(
            locationService: _InertLocationService(),
          ),
        ),
      ),
    );
    // pumpAndSettle would time out if an infinite animation were running.
    await tester.pumpAndSettle();
    expect(find.text('Enable location'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('no overflow at ${size.width.toInt()}w', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const LocationSetupScreen(locationService: _InertLocationService())));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
