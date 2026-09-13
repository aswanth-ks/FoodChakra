import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/features/give/domain/surplus_draft.dart';
import 'package:foodloop/features/give/presentation/review_publish_screen.dart';
import 'package:foodloop/features/partner/presentation/partner_surplus_providers.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/explore_view.dart';
import 'package:foodloop/features/rescue/presentation/impact_providers.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';

import 'support/fake_location_cache.dart';
import 'support/inert_location_service.dart';

FoodListing listing({
  String id = 'l1',
  String title = '25 Meal Boxes',
  String category = 'Vegetarian',
  ListingUrgency urgency = ListingUrgency.available,
  String? status,
  int? quantityCount,
  String? unit,
  int servings = 25,
}) => FoodListing(
  id: id,
  title: title,
  category: category,
  distanceKm: 1.4,
  imageAsset: 'assets/images/food_meal_boxes.jpg',
  urgency: urgency,
  servings: servings,
  pickupWindow: 'Today, 7:30 PM – 8:30 PM',
  pickupLocation: 'Community Hall',
  pickupLocality: 'Karur, Tamil Nadu',
  sharedBy: 'Asha Rao',
  description: 'Freshly prepared.',
  tags: const [],
  status: status,
  quantityCount: quantityCount,
  unit: unit,
);

/// Records the query it was asked for, so a test can prove a filter chip
/// actually reached the API rather than only changing its own colour.
class FakeListingRepository implements ListingRepository {
  FakeListingRepository({this.results = const [], this.owned = const []});

  List<FoodListing> results;

  /// What `/listings/mine` returns. Named `owned` because `mine` is the
  /// interface method it backs.
  List<FoodListing> owned;
  Failure? failWith;

  final List<({List<String> foodTypes, String? source})> queries = [];

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
    queries.add((foodTypes: foodTypes, source: source));
    if (failWith != null) throw failWith!;
    return results;
  }

  @override
  Future<FoodListing> byId(String id) async => results.first;

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async {
    if (failWith != null) throw failWith!;
    return owned;
  }

  @override
  Future<FoodListing> create(NewListing listing) async {
    if (failWith != null) throw failWith!;
    return results.first;
  }

  @override
  Future<FoodListing> cancel(String id, {String? reason}) async => results.first;
}

class FakeRescueRepository implements RescueRepository {
  FakeRescueRepository({this.rescues = const []});

  List<Rescue> rescues;

  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => rescues;

  @override
  Future<Rescue> byId(String rescueId) async => rescues.first;

  @override
  Future<Rescue> activeForListing(String listingId) async => rescues.first;

  @override
  Future<Rescue> claim(String listingId) async => rescues.first;

  @override
  Future<Rescue> markArrived(String rescueId) async => rescues.first;

  @override
  Future<Rescue> verifyHandover(String rescueId, {required String code}) async =>
      rescues.first;

  @override
  Future<Rescue> markCollected(String rescueId) async => rescues.first;

  @override
  Future<Rescue> cancel(String rescueId, {String? reason}) async =>
      rescues.first;

  @override
  Future<Rescue> startTravel(String rescueId) async => rescues.first;
}

Rescue completedRescue(FoodListing food) => Rescue(
  id: 'r1',
  reference: 'FL-20481',
  status: 'completed',
  stage: RescueStage.collected,
  isActive: false,
  listing: food,
);

ProviderContainer container({
  FakeListingRepository? listings,
  FakeRescueRepository? rescues,
}) {
  final container = ProviderContainer(
    // Riverpod retries a failed provider with backoff, which leaves a pending
    // timer the test binding rejects. Production keeps that behaviour; the
    // tests assert the first outcome.
    retry: (retryCount, error) => null,
    overrides: [
        // Nothing remembered from a previous launch, and no platform channel
        // to hang on. Tests that want a remembered fix seed it themselves.
        locationCacheProvider.overrideWithValue(FakeLocationCache()),
        // No platform channel for these tests to hang on either.
        locationServiceProvider.overrideWithValue(
          const InertLocationService(),
        ),
      if (listings != null)
        listingRepositoryProvider.overrideWithValue(listings),
      if (rescues != null) rescueRepositoryProvider.overrideWithValue(rescues),
      // A fixed origin keeps the tests off the platform location channel.
      currentOriginProvider.overrideWith(
        (ref) async => (latitude: 10.9577, longitude: 78.0809),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> show(WidgetTester tester, ProviderContainer c, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Explore filters reach the API', () {
    test('Vegetarian and Vegan narrow the query itself', () async {
      final repository = FakeListingRepository(results: [listing()]);
      final c = container(listings: repository);

      await c.read(exploreListingsProvider('Vegetarian').future);
      await c.read(exploreListingsProvider('Vegan').future);

      expect(repository.queries[0].foodTypes, ['vegetarian']);
      expect(repository.queries[1].foodTypes, ['vegan']);
    });

    test('Event food narrows by source', () async {
      final repository = FakeListingRepository(results: [listing()]);
      final c = container(listings: repository);

      await c.read(exploreListingsProvider('Event food').future);

      expect(repository.queries.single.source, 'event');
    });

    test('Nearby asks for everything, which is what the chip means', () async {
      final repository = FakeListingRepository(results: [listing()]);
      final c = container(listings: repository);

      await c.read(exploreListingsProvider('Nearby').future);

      expect(repository.queries.single.foodTypes, isEmpty);
      expect(repository.queries.single.source, isNull);
    });

    test('Expiring soon keeps only listings the server called urgent', () async {
      final repository = FakeListingRepository(
        results: [
          listing(id: 'a', urgency: ListingUrgency.available),
          listing(id: 'b', urgency: ListingUrgency.expiring),
          listing(id: 'c', urgency: ListingUrgency.critical),
        ],
      );
      final c = container(listings: repository);

      final result = await c.read(
        exploreListingsProvider('Expiring soon').future,
      );

      expect(result.map((l) => l.id), ['b', 'c']);
    });

    test('Ready now drops listings that have not opened yet', () async {
      final repository = FakeListingRepository(
        results: [
          listing(id: 'a', urgency: ListingUrgency.available),
          listing(id: 'b', urgency: ListingUrgency.scheduled),
        ],
      );
      final c = container(listings: repository);

      final result = await c.read(exploreListingsProvider('Ready now').future);

      expect(result.map((l) => l.id), ['a']);
    });
  });

  group('Explore states', () {
    testWidgets('an empty result gets the empty state, not an error', (
      tester,
    ) async {
      final c = container(listings: FakeListingRepository(results: const []));

      await show(tester, c, const ExploreView());

      expect(find.text('Nothing to rescue right now'), findsOneWidget);
    });

    testWidgets('an API failure shows the error and no listings', (
      tester,
    ) async {
      final repository = FakeListingRepository(results: [listing()])
        ..failWith = const NetworkFailure();
      final c = container(listings: repository);

      await show(tester, c, const ExploreView());

      // No fake fallback: the fixtures must not reappear on failure.
      expect(find.text('25 Meal Boxes'), findsNothing);
      expect(find.text('Nothing to rescue right now'), findsNothing);
    });

    testWidgets('real listings render', (tester) async {
      final c = container(
        listings: FakeListingRepository(results: [listing()]),
      );

      await show(tester, c, const ExploreView());

      expect(find.text('25 Meal Boxes'), findsWidgets);
    });
  });

  group('impact is computed from real records', () {
    test('a new account sees true zeroes, not sample figures', () async {
      final c = container(
        listings: FakeListingRepository(),
        rescues: FakeRescueRepository(),
      );

      final impact = await c.read(consumerImpactProvider.future);

      expect(impact.summary.rescues, 0);
      expect(impact.summary.mealBoxes, 0);
      expect(impact.summary.shares, 0);
      expect(impact.isEmpty, isTrue);
    });

    test('completed rescues are counted and summed', () async {
      final food = listing(quantityCount: 25, unit: 'meal_boxes', servings: 25);
      final c = container(
        listings: FakeListingRepository(),
        rescues: FakeRescueRepository(rescues: [completedRescue(food)]),
      );

      final impact = await c.read(consumerImpactProvider.future);

      expect(impact.summary.rescues, 1);
      expect(impact.summary.mealBoxes, 25);
      expect(impact.summary.servings, 25);
      expect(impact.recent.single.title, '25 Meal Boxes');
    });

    test('servings and kilograms are not silently counted as meal boxes', () async {
      final c = container(
        listings: FakeListingRepository(),
        rescues: FakeRescueRepository(
          rescues: [
            completedRescue(
              listing(quantityCount: 10, unit: 'kilograms', servings: 25),
            ),
          ],
        ),
      );

      final impact = await c.read(consumerImpactProvider.future);

      expect(impact.summary.mealBoxes, 0);
      expect(impact.summary.rescues, 1);
    });

    test('an in-flight rescue does not count as impact', () async {
      final c = container(
        listings: FakeListingRepository(),
        rescues: FakeRescueRepository(
          rescues: [
            Rescue(
              id: 'r1',
              reference: 'FL-1',
              status: 'onTheWay',
              stage: RescueStage.ready,
              isActive: true,
              listing: listing(quantityCount: 25, unit: 'meal_boxes'),
            ),
          ],
        ),
      );

      final impact = await c.read(consumerImpactProvider.future);

      expect(impact.summary.rescues, 0);
      expect(impact.summary.mealBoxes, 0);
    });
  });

  group('Give publish reports the server outcome', () {
    testWidgets('a rejected publish never shows the success state', (
      tester,
    ) async {
      var navigated = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPublishScreen(
            draft: const SurplusDraft(
              foodName: 'Biryani',
              quantity: 25,
              safetyConfirmed: true,
            ),
            // The backend refused it.
            onPublish: (_) async => false,
            onPublished: () => navigated = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Publish surplus food'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(navigated, isFalse);
      // Back to the idle label, not a confirmation.
      expect(find.text('Publish surplus food'), findsOneWidget);
    });

    testWidgets('an accepted publish confirms and then leaves the flow', (
      tester,
    ) async {
      var navigated = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPublishScreen(
            draft: const SurplusDraft(
              foodName: 'Biryani',
              quantity: 25,
              safetyConfirmed: true,
            ),
            onPublish: (_) async => true,
            onPublished: () => navigated = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Publish surplus food'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(navigated, isTrue);
    });
  });

  group('partner dashboard is computed from real listings', () {
    test('an account with no listings reports zeroes', () async {
      final c = container(
        listings: FakeListingRepository(),
        rescues: FakeRescueRepository(),
      );

      final dashboard = await c.read(partnerDashboardProvider.future);

      expect(dashboard.batchCount, 0);
      expect(dashboard.activeRescues, 0);
      expect(dashboard.rescuesComplete, 0);
      // No history means no rate; 100% would be a lie.
      expect(dashboard.completionRate, 0);
      expect(dashboard.recentActivity, isEmpty);
      expect(dashboard.pickupSoonDetail, 'Nothing closing soon');
    });

    test('live and finished listings are counted separately', () async {
      final repository = FakeListingRepository(
        owned: [
          listing(id: 'a', status: 'published'),
          listing(id: 'b', status: 'matched'),
          listing(id: 'c', status: 'completed', servings: 12),
          listing(id: 'd', status: 'expired'),
        ],
      );
      final c = container(listings: repository, rescues: FakeRescueRepository());

      final dashboard = await c.read(partnerDashboardProvider.future);

      expect(dashboard.batchCount, 2);
      expect(dashboard.activeRescues, 1);
      expect(dashboard.rescuesComplete, 1);
      expect(dashboard.portionsShared, 12);
      // One of two finished listings was collected.
      expect(dashboard.completionRate, 50);
      expect(dashboard.activeSurplus.map((s) => s.id), ['a', 'b']);
    });

    test('surplus rows carry real listing ids for the handover route', () async {
      final repository = FakeListingRepository(
        owned: [listing(id: '68c0f1a2b3c4d5e6f7a8b9c0', status: 'matched')],
      );
      final c = container(listings: repository, rescues: FakeRescueRepository());

      final dashboard = await c.read(partnerDashboardProvider.future);

      expect(dashboard.activeSurplus.single.id, '68c0f1a2b3c4d5e6f7a8b9c0');
    });
  });
}
