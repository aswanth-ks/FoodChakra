import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';
import 'package:foodloop/features/rescue/domain/rescue.dart';
import 'package:foodloop/features/rescue/domain/rescue_repository.dart';
import 'package:foodloop/features/rescue/presentation/active_rescue_view.dart';
import 'package:foodloop/features/rescue/presentation/handover_confirmation_view.dart';
import 'package:foodloop/features/rescue/presentation/rescue_providers.dart';

const _listing = FoodListing(
  id: 'l1',
  title: '25 Meal Boxes',
  category: 'Vegetarian',
  distanceKm: 1.4,
  imageAsset: 'assets/images/food_meal_boxes.jpg',
  urgency: ListingUrgency.available,
  servings: 25,
  pickupWindow: 'Today, 7:30 PM – 8:30 PM',
  pickupLocation: 'Community Hall',
  sharedBy: 'Asha Rao',
  description: 'Freshly prepared.',
  tags: ['Plant-Based'],
  status: 'matched',
);

Rescue rescueAt(String status, {String? code}) => Rescue(
  id: 'r1',
  reference: 'FL-20481',
  status: status,
  stage: switch (status) {
    'matched' => RescueStage.confirmed,
    'onTheWay' => RescueStage.ready,
    'arrived' || 'verified' => RescueStage.pickup,
    'collected' || 'completed' => RescueStage.collected,
    _ => null,
  },
  isActive: status != 'completed' && status != 'cancelled',
  listing: _listing,
  handoverCode: code,
);

/// Records calls and returns whatever the test scripts.
class FakeRescueRepository implements RescueRepository {
  FakeRescueRepository({required this.current});

  Rescue current;
  final List<String> calls = [];

  /// Fails a mutation (arrive / verify / collect).
  Failure? failWith;

  /// Fails the owner's lookup, i.e. the backend refusing to resolve the
  /// rescue at all.
  Failure? failLookup;

  @override
  Future<Rescue> byId(String rescueId) async => current;

  @override
  Future<Rescue> claim(String listingId) async {
    calls.add('claim:$listingId');
    return current;
  }

  @override
  Future<Rescue> activeForListing(String listingId) async {
    calls.add('activeForListing:$listingId');
    if (failLookup != null) throw failLookup!;
    return current;
  }

  @override
  Future<Rescue> markArrived(String rescueId) async {
    calls.add('markArrived:$rescueId');
    if (failWith != null) throw failWith!;
    current = rescueAt('arrived', code: '481920');
    return current;
  }

  @override
  Future<Rescue> verifyHandover(String rescueId, {required String code}) async {
    calls.add('verify:$rescueId:$code');
    if (failWith != null) throw failWith!;
    current = rescueAt('verified');
    return current;
  }

  @override
  Future<Rescue> markCollected(String rescueId) async {
    calls.add('markCollected:$rescueId');
    if (failWith != null) throw failWith!;
    current = rescueAt('completed');
    return current;
  }

  @override
  Future<Rescue> cancel(String rescueId, {String? reason}) async {
    calls.add('cancel:$rescueId');
    current = rescueAt('cancelled');
    return current;
  }

  @override
  Future<Rescue> startTravel(String rescueId) async {
    calls.add('startTravel:$rescueId');
    if (failWith != null) throw failWith!;
    current = rescueAt('onTheWay');
    return current;
  }

  @override
  Future<List<Rescue>> mine({bool activeOnly = false}) async => [current];
}

Widget harness(FakeRescueRepository repository, Widget child) {
  return ProviderScope(
    overrides: [rescueRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: child),
  );
}

/// Pumps on a realistic phone surface.
///
/// The default 800x600 test window is shorter than any phone, which makes the
/// sticky action bar collide with the content — an artefact of the harness,
/// not of the layout.
Future<void> show(
  WidgetTester tester,
  FakeRescueRepository repository,
  Widget child,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(harness(repository, child));
  // Fixed pumps rather than pumpAndSettle: the loading state runs a spinner,
  // which never settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('rescuer side', () {
    testWidgets('an on-the-way rescue offers "I\'ve arrived"', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('onTheWay'));

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));

      expect(find.text("I've arrived"), findsOneWidget);
      // Collection is not offered before the handover is confirmed.
      expect(find.text('I have collected this food'), findsNothing);
    });

    testWidgets('arriving calls the API and shows the one-time code', (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('onTheWay'));

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text("I've arrived"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.calls, contains('markArrived:r1'));
      expect(find.text('Your handover code'), findsOneWidget);
      // Grouped 3-3 so it is easy to read aloud.
      expect(find.text('481 920'), findsOneWidget);
    });

    testWidgets("a matched rescue offers navigation and I'm on my way", (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('matched'));

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));

      expect(find.text('Start navigation'), findsOneWidget);
      expect(find.text("I'm on my way"), findsOneWidget);
      // Nothing further is offered until the rescuer has actually set off.
      expect(find.text("I've arrived"), findsNothing);
      expect(find.text('I have collected this food'), findsNothing);
    });

    testWidgets('opening maps alone does not change the rescue', (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('matched'));

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text('Start navigation'));
      await tester.pump(const Duration(milliseconds: 50));

      // Looking at a route is not travelling. The rescue must stay `matched`.
      expect(repository.calls, isNot(contains('startTravel:r1')));
      expect(repository.current.status, 'matched');
      expect(find.text("I'm on my way"), findsOneWidget);
    });

    testWidgets('confirming departure calls the API and reveals arrival', (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('matched'));

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text("I'm on my way"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.calls, contains('startTravel:r1'));
      expect(find.text("I've arrived"), findsOneWidget);
      expect(find.text("I'm on my way"), findsNothing);
    });

    testWidgets('a 409 leaves the rescue matched', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('matched'))
        ..failWith = const UnknownFailure(
          'A rescue that is onTheWay cannot become onTheWay.',
        );

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text("I'm on my way"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.current.status, 'matched');
      // Still offering departure, never pretending it happened.
      expect(find.text("I'm on my way"), findsOneWidget);
      expect(find.text("I've arrived"), findsNothing);
      expect(
        find.text('A rescue that is onTheWay cannot become onTheWay.'),
        findsOneWidget,
      );
    });

    testWidgets('a 403 is surfaced and changes nothing', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('matched'))
        ..failWith = const ForbiddenFailure(
          'You do not have permission to do this.',
        );

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text("I'm on my way"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.current.status, 'matched');
      expect(
        find.text('You do not have permission to do this.'),
        findsOneWidget,
      );
    });

    testWidgets('a network failure leaves the rescue matched', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('matched'))
        ..failWith = const NetworkFailure();

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text("I'm on my way"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.current.status, 'matched');
      expect(find.text("I've arrived"), findsNothing);
    });

    testWidgets('collection is offered only once verified', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('verified'));

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));

      expect(find.text('I have collected this food'), findsOneWidget);
      expect(find.text("I've arrived"), findsNothing);
    });

    testWidgets('collecting calls the real endpoint and completes', (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('verified'));
      var completed = false;

      await show(tester, repository, ActiveRescueView(
            rescueId: 'r1',
            onCompleted: (_) => completed = true,
          ));
      await tester.tap(find.text('I have collected this food'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.calls, contains('markCollected:r1'));
      expect(completed, isTrue);
    });

    testWidgets('a server failure does not fake local success', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('onTheWay'))
        ..failWith = const UnknownFailure('Someone else got there first.');

      await show(tester, repository, const ActiveRescueView(rescueId: 'r1'));
      await tester.tap(find.text("I've arrived"));
      await tester.pump(const Duration(milliseconds: 50));

      // The code never appears, because the server never issued one.
      expect(find.text('Your handover code'), findsNothing);
      expect(find.text('Someone else got there first.'), findsOneWidget);
    });
  });

  group('owner side', () {
    testWidgets('the owner is asked for the code', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('arrived'));

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));

      expect(find.text('Confirm the handover'), findsOneWidget);
      expect(find.text('25 Meal Boxes'), findsOneWidget);
      // Resolved from the listing the owner knows, not a rescue id.
      expect(repository.calls, contains('activeForListing:l1'));
    });

    testWidgets('a short code is rejected before any API call', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('arrived'));

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Confirm handover'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('Enter the six digits the rescuer read out.'),
        findsOneWidget,
      );
      expect(repository.calls.where((c) => c.startsWith('verify')), isEmpty);
    });

    testWidgets('the field refuses non-digits', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('arrived'));

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));
      await tester.enterText(find.byType(TextField), 'ab12cd34');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '1234');
    });

    testWidgets('a valid code verifies through the repository', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('arrived'));

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));
      await tester.enterText(find.byType(TextField), '481920');
      await tester.tap(find.text('Confirm handover'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.calls, contains('verify:r1:481920'));
      expect(find.text('Handover confirmed'), findsOneWidget);
    });

    testWidgets('a rejected code shows the server message, not success', (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('arrived'))
        ..failWith = const ForbiddenFailure('That handover code is not correct.');

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Confirm handover'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('That handover code is not correct.'), findsOneWidget);
      expect(find.text('Handover confirmed'), findsNothing);
    });

    testWidgets('an expired code shows the server message', (tester) async {
      final repository = FakeRescueRepository(current: rescueAt('arrived'))
        ..failWith = const UnknownFailure('That handover code has expired.');

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));
      await tester.enterText(find.byType(TextField), '481920');
      await tester.tap(find.text('Confirm handover'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('That handover code has expired.'), findsOneWidget);
      expect(find.text('Handover confirmed'), findsNothing);
    });

    testWidgets('an unauthorised owner sees the error, not the code field', (
      tester,
    ) async {
      // The backend refuses to resolve the rescue at all.
      final repository = FakeRescueRepository(current: rescueAt('arrived'))
        ..failLookup = const ForbiddenFailure(
          'You cannot confirm this handover.',
        );

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Confirm the handover'), findsNothing);
    });

    testWidgets('an already-verified rescue shows the confirmed state', (
      tester,
    ) async {
      final repository = FakeRescueRepository(current: rescueAt('verified'));

      await show(tester, repository, const HandoverConfirmationView(listingId: 'l1'));

      expect(find.text('Handover confirmed'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
