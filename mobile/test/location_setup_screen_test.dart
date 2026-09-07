import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/location/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:foodloop/features/onboarding/presentation/location_setup_screen.dart';

/// Stands in for the real geolocator call so tests never touch a platform
/// channel and can control the outcome.
class _FakeLocationService implements LocationService {
  _FakeLocationService(this.result);

  final LocationResult result;
  bool called = false;

  /// Lets a test observe the loading state before the result resolves,
  /// rather than racing a Future that completes within the same microtask.
  final _completer = Completer<void>();

  @override
  Future<LocationResult> requestLocation() async {
    called = true;
    await _completer.future;
    return result;
  }

  void resolve() => _completer.complete();
}

Widget _wrap(Widget c) => MaterialApp(theme: AppTheme.light, home: c);

void main() {
  testWidgets('renders the Stitch copy and map markers', (tester) async {
    await tester.pumpWidget(_wrap(const LocationSetupScreen()));
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

  testWidgets('Enable location calls the real service and continues on grant', (
    tester,
  ) async {
    final fake = _FakeLocationService(
      LocationResult(
        LocationOutcome.granted,
        position: Position(
          latitude: 12.9,
          longitude: 77.6,
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      ),
    );
    LocationOutcome? seen;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(locationService: fake, onContinue: (o) => seen = o),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Enable location'));
    await tester.pump(); // enter the loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fake.resolve();
    // Not pumpAndSettle: the radar pulse loops forever, so this only
    // advances far enough for the resolved Future and the snackbar to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(fake.called, isTrue);
    expect(seen, LocationOutcome.granted);
    expect(find.text('Location enabled (12.9000, 77.6000).'), findsOneWidget);
  });

  testWidgets('continues even when the plugin is unavailable', (tester) async {
    final fake = _FakeLocationService(
      const LocationResult(LocationOutcome.unavailable),
    );
    LocationOutcome? seen;

    await tester.pumpWidget(
      _wrap(
        LocationSetupScreen(locationService: fake, onContinue: (o) => seen = o),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Enable location'));
    await tester.pump();
    fake.resolve();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(seen, LocationOutcome.unavailable);
  });

  testWidgets('Skip and Not now continue without requesting location', (
    tester,
  ) async {
    final fake = _FakeLocationService(
      const LocationResult(LocationOutcome.granted),
    );

    for (final label in ['Skip', 'Not now']) {
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
          child: LocationSetupScreen(),
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

      await tester.pumpWidget(_wrap(const LocationSetupScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
