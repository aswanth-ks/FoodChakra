import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/features/rescue/data/rescue_dto.dart';
import 'package:foodloop/features/rescue/domain/food_listing.dart';

void main() {
  Map<String, dynamic> json({String status = 'matched', String? stage = 'confirmed'}) {
    final now = DateTime.now();
    return {
      'id': 'r1',
      'reference': 'FL-20481',
      'status': status,
      'stage': stage,
      'is_active': status != 'cancelled',
      'distance_km': 1.4,
      'cancel_reason': null,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
      'listing': {
        'id': 'l1',
        'reference': 'FL-20481',
        'title': '25 Meal Boxes',
        'category': 'Vegetarian',
        'quantity_label': 'Approx. 25 servings',
        'servings': 25,
        'pickup_location': {
          'label': 'Community Hall',
          'locality': 'Karur, Tamil Nadu',
          'latitude': 10.9577,
          'longitude': 78.0809,
        },
        'pickup_from': now.toUtc().toIso8601String(),
        'pickup_until': now.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'shared_by': 'Community Event Organizer',
        'shared_by_verified': true,
        'description': 'Freshly prepared.',
        'tags': ['Plant-Based'],
      },
    };
  }

  test('maps a rescue and its listing snapshot', () {
    final rescue = RescueDto.fromJson(json()).toDomain();

    expect(rescue.id, 'r1');
    expect(rescue.reference, 'FL-20481');
    expect(rescue.status, 'matched');
    expect(rescue.stage, RescueStage.confirmed);
    expect(rescue.isActive, isTrue);
    expect(rescue.listing.title, '25 Meal Boxes');
    expect(rescue.listing.pickupLocation, 'Community Hall');
    // The distance is lifted onto the listing so the cards render unchanged.
    expect(rescue.listing.distanceKm, 1.4);
  });

  test('maps the stepper projection the server computes', () {
    for (final (wire, expected) in [
      ('confirmed', RescueStage.confirmed),
      ('preparing', RescueStage.preparing),
      ('ready', RescueStage.ready),
      ('pickup', RescueStage.pickup),
      ('collected', RescueStage.collected),
    ]) {
      expect(RescueDto.fromJson(json(stage: wire)).toDomain().stage, expected);
    }
  });

  test('a rescue off the stepper has no stage', () {
    final rescue =
        RescueDto.fromJson(json(status: 'cancelled', stage: null)).toDomain();

    expect(rescue.stage, isNull);
    expect(rescue.isActive, isFalse);
  });

  test('carries the handover code when the server sends one', () {
    final withCode = RescueDto.fromJson({
      ...json(status: 'arrived', stage: 'pickup'),
      'handover_code': '481920',
    }).toDomain();

    expect(withCode.handoverCode, '481920');
  });

  test('has no handover code when the server withholds it', () {
    // The code is returned once, to the rescuer, on arrival — never on a
    // later read and never to the person confirming the handover.
    expect(RescueDto.fromJson(json()).toDomain().handoverCode, isNull);
  });

  test('an unknown stage does not guess a position on the stepper', () {
    expect(RescueDto.fromJson(json(stage: 'teleporting')).toDomain().stage, isNull);
  });
}
