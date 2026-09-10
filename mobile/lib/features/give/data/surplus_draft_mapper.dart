import '../../rescue/domain/listing_repository.dart';
import '../domain/surplus_draft.dart';

/// Maps the Give flow's UI draft onto the listings API's request shape.
///
/// The mapping lives here rather than in the draft or the repository because
/// it is where two vocabularies meet: `SurplusDraft` speaks in `TimeOfDay` and
/// `PickupDay` because that is what the pickers produce, while the API needs
/// absolute UTC instants. Doing the conversion once, at publish time, keeps
/// both sides clean.
extension SurplusDraftMapper on SurplusDraft {
  /// Resolves the pickup day and time pickers into a real date.
  DateTime _resolve(TimeOfDayLike time, {required DateTime base}) =>
      DateTime(base.year, base.month, base.day, time.hour, time.minute);

  DateTime get pickupFromDateTime =>
      _resolve(TimeOfDayLike(pickupFrom.hour, pickupFrom.minute), base: _day);

  DateTime get pickupUntilDateTime {
    final from = pickupFromDateTime;
    final until = _resolve(
      TimeOfDayLike(pickupUntil.hour, pickupUntil.minute),
      base: _day,
    );
    // A window that ends before it starts has crossed midnight.
    return until.isAfter(from) ? until : until.add(const Duration(days: 1));
  }

  DateTime get _day {
    final now = DateTime.now();
    return switch (pickupDay) {
      PickupDay.today => now,
      PickupDay.tomorrow => now.add(const Duration(days: 1)),
      PickupDay.custom => customDate ?? now,
    };
  }

  /// The API request for this draft, at the given pickup coordinates.
  NewListing toNewListing({
    required double latitude,
    required double longitude,
    String? locality,
  }) => NewListing(
    foodName: foodName.trim(),
    foodType: _foodTypeWire(foodType),
    quantity: quantity ?? 0,
    unit: _unitWire(unit),
    safetyConfirmed: safetyConfirmed,
    source: _sourceWire(source),
    preparedWhen: _preparedWhenWire(preparedWhen),
    pickupLabel: pickupLocation,
    pickupLocality: locality,
    latitude: latitude,
    longitude: longitude,
    pickupFrom: pickupFromDateTime,
    pickupUntil: pickupUntilDateTime,
  );
}

/// A `TimeOfDay` without the Flutter import, so this file stays testable.
class TimeOfDayLike {
  const TimeOfDayLike(this.hour, this.minute);

  final int hour;
  final int minute;
}

String _foodTypeWire(FoodType? type) => switch (type) {
  FoodType.vegetarian => 'vegetarian',
  FoodType.vegan => 'vegan',
  FoodType.nonVeg => 'non_veg',
  _ => 'other',
};

String _unitWire(QuantityUnit unit) => switch (unit) {
  QuantityUnit.mealBoxes => 'meal_boxes',
  QuantityUnit.servings => 'servings',
  QuantityUnit.kilograms => 'kilograms',
};

String? _sourceWire(SurplusSource? source) => switch (source) {
  SurplusSource.home => 'home',
  SurplusSource.event => 'event',
  _ => null,
};

String _preparedWhenWire(PreparedWhen when) => switch (when) {
  PreparedWhen.justPrepared => 'just_prepared',
  PreparedWhen.earlierToday => 'earlier_today',
  PreparedWhen.yesterday => 'yesterday',
  PreparedWhen.other => 'other',
};
