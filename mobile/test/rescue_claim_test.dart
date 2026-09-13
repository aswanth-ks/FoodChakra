import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/core/network/error_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/food_details_screen.dart';
import 'package:foodloop/features/rescue/presentation/food_details_view.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';

import 'support/fake_location_cache.dart';
import 'support/inert_location_service.dart';

/// Answers every request with one fixed status and body.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

FoodListing listing({String id = '68c1f0a2e4b09a77c3d51234'}) => FoodListing(
  id: id,
  title: '25 Meal Boxes',
  category: 'Vegetarian',
  distanceKm: 1.4,
  imageAsset: 'assets/images/food_meal_boxes.jpg',
  urgency: ListingUrgency.available,
  servings: 25,
  pickupWindow: 'Today, 7:30 PM – 8:30 PM',
  pickupLocation: 'Community Hall',
  pickupLocality: 'Karur, Tamil Nadu',
  sharedBy: 'Asha Rao',
  description: 'Freshly prepared.',
  tags: const [],
);

Rescue rescue(FoodListing food, {String id = '68c1f0a2e4b09a77c3d59999'}) =>
    Rescue(
      id: id,
      reference: 'FL-20481',
      status: 'matched',
      stage: RescueStage.confirmed,
      isActive: true,
      listing: food,
    );

/// Counts claims so a double tap can be proved not to become a second claim.
class CountingRescues implements RescueRepository {
  CountingRescues(this.food);

  final FoodListing food;
  Failure? failWith;
  int claimCalls = 0;
  Completer<void>? gate;

  @override
  Future<Rescue> claim(String listingId) async {
    claimCalls++;
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
    return rescue(food);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class CountingListings implements ListingRepository {
  CountingListings(this.food);

  final FoodListing food;
  Failure? detailFailure;
  int byIdCalls = 0;

  @override
  Future<FoodListing> byId(String id) async {
    byIdCalls++;
    if (detailFailure != null) throw detailFailure!;
    return food;
  }

  @override
  Future<List<FoodListing>> nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
    List<String> foodTypes = const [],
    String? source,
    int limit = 20,
    int offset = 0,
  }) async => const [];

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
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

  late FoodListing food;
  late CountingRescues rescues;
  late CountingListings listings;

  setUp(() {
    food = listing();
    rescues = CountingRescues(food);
    listings = CountingListings(food);
  });

  Future<String?> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? claimedRescueId;
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        // No platform channel for these tests to hang on either.
        locationServiceProvider.overrideWithValue(
          const InertLocationService(),
        ),
        listingRepositoryProvider.overrideWithValue(listings),
        rescueRepositoryProvider.overrideWithValue(rescues),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: FoodDetailsView(
            listingId: food.id,
            onClaimed: (id) => claimedRescueId = id,
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return claimedRescueId;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Taps Rescue, ticks the commitment checkbox, then confirms.
  ///
  /// The sheet keeps Confirm disabled until the user commits to collecting
  /// within the pickup window, so the checkbox is part of the real path.
  Future<void> tapRescue(WidgetTester tester) async {
    await tester.tap(find.text('Rescue this food'));
    await settle(tester);
    await tester.tap(find.text('I can collect within this pickup window.'));
    await settle(tester);
    await tester.tap(find.text('Confirm rescue'));
    await settle(tester);
  }

  group('409 mapping', () {
    test('a conflict becomes a ConflictFailure carrying the server wording', () async {
      // Driven through a real Dio so the mapping is exercised exactly as it
      // is in production, rather than by calling a private helper.
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = _StatusAdapter(
          409,
          '{"error":{"code":"CONFLICT",'
              '"message":"Someone else has just rescued this food."}}',
        )
        ..interceptors.add(ErrorInterceptor());

      Object? captured;
      try {
        await dio.post<Map<String, dynamic>>('/rescues');
      } on DioException catch (e) {
        captured = e.error;
      }

      // Before this mapping existed a 409 fell through to UnknownFailure,
      // which no caller could tell apart from a genuine malfunction.
      expect(captured, isA<ConflictFailure>());
      expect(
        (captured! as Failure).message,
        'Someone else has just rescued this food.',
      );
    });
  });

  group('claiming', () {
    testWidgets('a successful claim uses the id the server returned', (
      tester,
    ) async {
      final claimed = <String?>[];
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
          listingRepositoryProvider.overrideWithValue(listings),
          rescueRepositoryProvider.overrideWithValue(rescues),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: FoodDetailsView(
              listingId: food.id,
              onClaimed: claimed.add,
            ),
          ),
        ),
      );
      await settle(tester);

      await tapRescue(tester);

      expect(rescues.claimCalls, 1);
      // The server's rescue id, not one invented on the device.
      expect(claimed.single, '68c1f0a2e4b09a77c3d59999');
    });

    testWidgets('a second tap while the claim is in flight is ignored', (
      tester,
    ) async {
      rescues.gate = Completer<void>();

      await show(tester);
      await tester.tap(find.text('Rescue this food'));
      await settle(tester);
      await tester.tap(find.text('I can collect within this pickup window.'));
      await settle(tester);
      await tester.tap(find.text('Confirm rescue'));
      // Only far enough for the sheet to close and the claim to start.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The button is replaced by a spinner for the duration, so there is
      // nothing left to tap twice.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Rescue this food'), findsNothing);

      rescues.gate!.complete();
      await settle(tester);

      expect(rescues.claimCalls, 1);
    });

    testWidgets('a conflict shows the server wording and re-reads the listing', (
      tester,
    ) async {
      rescues.failWith = const ConflictFailure(
        'Someone else has just rescued this food.',
      );

      await show(tester);
      final readsBefore = listings.byIdCalls;

      await tapRescue(tester);

      expect(find.text('Someone else has just rescued this food.'), findsWidgets);
      // Refreshed, so a card the server has already given away does not sit
      // there still offering a rescue button.
      expect(listings.byIdCalls, greaterThan(readsBefore));
    });

    testWidgets('rescuing your own listing reports the server refusal', (
      tester,
    ) async {
      // The backend refuses this; the client only relays it.
      rescues.failWith = const ConflictFailure(
        'You cannot rescue food you published yourself.',
      );

      final claimed = await show(tester);
      await tapRescue(tester);

      expect(
        find.text('You cannot rescue food you published yourself.'),
        findsWidgets,
      );
      expect(claimed, isNull);
    });

    testWidgets('a network failure does not fake a rescue', (tester) async {
      rescues.failWith = const NetworkFailure();

      final claimed = await show(tester);
      await tapRescue(tester);

      expect(claimed, isNull);
      // The button comes back so the user can try again.
      expect(find.text('Rescue this food'), findsWidgets);
    });

    testWidgets('a vanished listing shows the unavailable state', (
      tester,
    ) async {
      listings.detailFailure = const NotFoundFailure('Not found.');

      await show(tester);

      expect(find.text('This food is no longer available'), findsOneWidget);
      // No rescue button on something that is gone.
      expect(find.text('Rescue this food'), findsNothing);
    });

    testWidgets('the details screen shows the real listing', (tester) async {
      await show(tester);

      expect(find.byType(FoodDetailsScreen), findsOneWidget);
      expect(find.text('25 Meal Boxes'), findsWidgets);
    });
  });
}
