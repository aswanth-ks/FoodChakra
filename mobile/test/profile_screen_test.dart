import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/router.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/features/auth/domain/account.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';
import 'package:foodloop/features/auth/domain/auth_repository.dart';
import 'package:foodloop/features/auth/presentation/auth_providers.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/listing_repository.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/listing_providers.dart';
import 'package:foodloop/features/rescue/presentation/profile_screen.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';

import 'support/fake_location_cache.dart';
import 'support/inert_location_service.dart';

/// The account the backend is pretending to return from `GET /auth/me`.
///
/// Fixtures live in the test only. Production has no equivalent: the profile
/// takes its values from the session and the user's own completed records.
Account account({
  String fullName = 'Asha Rao',
  String email = 'asha@example.com',
  AccountRole role = AccountRole.consumer,
  bool emailVerified = true,
  DateTime? createdAt,
}) => Account(
  id: 'u1',
  email: email,
  fullName: fullName,
  role: role,
  status: AccountStatus.active,
  emailVerified: emailVerified,
  createdAt: createdAt,
);

FoodListing listing({
  String id = 'l1',
  String title = '25 Meal Boxes',
  String? status,
  int? quantityCount,
  String? unit,
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
  sharedBy: 'Asha Rao',
  description: 'Freshly prepared.',
  tags: const [],
  status: status,
  quantityCount: quantityCount,
  unit: unit,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.restored);

  Account? restored;
  int signOutCalls = 0;

  @override
  Future<Account?> restoreSession() async => restored;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    restored = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// Serves the user's own completed records, or fails on demand.
class FakeListingRepository implements ListingRepository {
  FakeListingRepository({this.owned = const []});

  List<FoodListing> owned;
  Failure? failWith;
  int mineCalls = 0;

  /// Never answers, so a test can look at what the screen shows while the
  /// totals are still in flight.
  bool hold = false;

  @override
  Future<List<FoodListing>> mine({List<String> statuses = const []}) async {
    mineCalls++;
    if (hold) return Completer<List<FoodListing>>().future;
    if (failWith != null) throw failWith!;
    return owned;
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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class FakeRescueRepository implements RescueRepository {
  FakeRescueRepository({this.owned = const []});

  List<Rescue> owned;

  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => owned;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Rescue completedRescue(FoodListing food) => Rescue(
  id: 'r1',
  reference: 'FL-20481',
  status: 'completed',
  stage: RescueStage.collected,
  isActive: false,
  listing: food,
);

void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/PlusJakartaSans[wght].ttf').readAsBytesSync();
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  late FakeAuthRepository auth;
  late FakeListingRepository listings;
  late FakeRescueRepository rescues;

  setUp(() {
    auth = FakeAuthRepository(account());
    listings = FakeListingRepository();
    rescues = FakeRescueRepository();
  });

  /// Pumps the real router at /profile, so every assertion is about the
  /// screen the app actually builds.
  Future<GoRouter> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
        authRepositoryProvider.overrideWithValue(auth),
        listingRepositoryProvider.overrideWithValue(listings),
        rescueRepositoryProvider.overrideWithValue(rescues),
        currentOriginProvider.overrideWith(
          (ref) async => (latitude: 10.9, longitude: 78.0),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    router.go('/profile');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return router;
  }

  testWidgets('name and email come from the authenticated account', (
    tester,
  ) async {
    auth.restored = account(
      fullName: 'Meera Nair',
      email: 'meera@foodloop.test',
    );

    await pumpProfile(tester);

    expect(find.text('Meera Nair'), findsOneWidget);
    expect(find.text('meera@foodloop.test'), findsOneWidget);
    // The old hardcoded identity must be gone for good.
    expect(find.text('Aswanth'), findsNothing);
  });

  testWidgets('the role shown is the one the server assigned', (tester) async {
    auth.restored = account(role: AccountRole.consumer);
    await pumpProfile(tester);
    expect(find.text('Consumer'), findsOneWidget);
    expect(find.text('Partner'), findsNothing);
  });

  testWidgets('an unverified address is reported as such', (tester) async {
    auth.restored = account(emailVerified: false);
    await pumpProfile(tester);
    expect(find.text('Unverified'), findsOneWidget);
  });

  testWidgets('a verified address shows no warning', (tester) async {
    auth.restored = account(emailVerified: true);
    await pumpProfile(tester);
    expect(find.text('Unverified'), findsNothing);
  });

  testWidgets('membership year comes from the account, and is omitted when '
      'the server gave none', (tester) async {
    auth.restored = account(createdAt: DateTime.utc(2025, 3, 4));
    await pumpProfile(tester);
    expect(find.text('FoodLoop member since 2025'), findsOneWidget);
    // Nothing invented for an account without one.
    expect(find.text('FoodLoop member since 2026'), findsNothing);
  });

  testWidgets('no membership line when the server gave no creation date', (
    tester,
  ) async {
    auth.restored = account();
    await pumpProfile(tester);
    expect(find.textContaining('FoodLoop member since'), findsNothing);
  });

  testWidgets('statistics are counted from real completed records', (
    tester,
  ) async {
    rescues.owned = [
      completedRescue(
        listing(quantityCount: 12, unit: 'meal_boxes', status: 'completed'),
      ),
    ];
    listings.owned = [
      listing(id: 'l2', status: 'completed'),
      listing(id: 'l3', status: 'completed'),
      // Not completed, so it must not be counted.
      listing(id: 'l4', status: 'claimed'),
    ];

    await pumpProfile(tester);

    expect(find.text('12'), findsOneWidget); // meal boxes rescued
    expect(find.text('2'), findsOneWidget); // food shares
    // The old invented figures.
    expect(find.text('48'), findsNothing);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('a brand new account renders real zeroes', (tester) async {
    rescues.owned = const [];
    listings.owned = const [];

    await pumpProfile(tester);

    // Zero is a true answer, not an error and not an empty state.
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Meal boxes rescued'), findsOneWidget);
    expect(find.text('Food shares'), findsOneWidget);
  });

  testWidgets('no weight is shown, because none is captured', (tester) async {
    await pumpProfile(tester);
    // The Give flow never asks for a weight, so any "kg" here would be
    // fabricated.
    expect(find.textContaining('kg'), findsNothing);
  });

  testWidgets('a failed totals query leaves the rest of Profile working', (
    tester,
  ) async {
    listings.failWith = const NetworkFailure();

    await pumpProfile(tester);

    // The identity came from the session and never depended on the two
    // requests that failed, so it is still on screen. Profile used to be
    // replaced wholesale by an error page here, hiding a name and email it
    // already had in hand.
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Asha Rao'), findsWidgets);
    expect(find.text('asha@example.com'), findsOneWidget);

    // Only the totals report the problem, and they offer a way out.
    expect(find.text("Couldn't load your totals."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // No number is invented to fill the gap — not even a zero, which would be
    // a claim about this account.
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('48'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Try again calls the backend again and recovers', (tester) async {
    listings.failWith = const NetworkFailure();
    await pumpProfile(tester);
    expect(find.text("Couldn't load your totals."), findsOneWidget);

    final callsBeforeRetry = listings.mineCalls;
    listings.failWith = null;
    listings.owned = [listing(id: 'l2', status: 'completed')];

    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The retry really went back to the repository.
    expect(listings.mineCalls, greaterThan(callsBeforeRetry));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    // And the error is gone, so the state actually terminated.
    expect(find.text("Couldn't load your totals."), findsNothing);
  });

  testWidgets('identity is drawn before the totals arrive', (tester) async {
    // The totals never resolve for the length of this test.
    listings.hold = true;

    await pumpProfile(tester);

    // First paint already has everything that came from the session.
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    // The totals say they are still coming rather than showing a figure.
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('signing out leaves the profile', (tester) async {
    final router = await pumpProfile(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    // The button sits at the bottom of a long scrolling list.
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pump();
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    // Confirm in the dialog — signing out is never a single tap.
    await tester.tap(find.text('Sign out').last);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(auth.signOutCalls, 1);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      isNot(contains('/profile')),
    );
  });
}
