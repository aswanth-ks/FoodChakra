import 'package:flutter/material.dart' show DayPeriod, TimeOfDay;

/// Where the surplus came from — the Give entry screen's only question.
enum SurplusSource {
  home('From home'),
  event('From an event');

  const SurplusSource(this.label);

  final String label;
}

/// Dietary category. `Non-veg` and `Other` are the design's own wording.
enum FoodType {
  vegetarian('Vegetarian'),
  vegan('Vegan'),
  nonVeg('Non-veg'),
  other('Other');

  const FoodType(this.label);

  final String label;
}

/// How the amount is counted.
enum QuantityUnit {
  mealBoxes('Meal boxes', 'Meal Boxes'),
  servings('Servings / Portions', 'Servings'),
  kilograms('Kilograms (kg)', 'kg');

  const QuantityUnit(this.label, this.shortLabel);

  /// The dropdown's wording.
  final String label;

  /// The wording used in summaries, e.g. "25 Meal Boxes".
  final String shortLabel;
}

/// When the food was made.
enum PreparedWhen {
  justPrepared('Just prepared', 'just prepared'),
  earlierToday('Earlier today', 'prepared earlier today'),
  yesterday('Yesterday', 'prepared yesterday'),
  other('Other', 'prepared earlier');

  const PreparedWhen(this.label, this.summaryLabel);

  /// The chip's wording.
  final String label;

  /// How it reads in a sentence on the review screen.
  final String summaryLabel;
}

/// Which day the pickup window falls on.
enum PickupDay {
  today('Today', 'Recommended'),
  tomorrow('Tomorrow', 'Next day'),
  custom('Custom', 'Pick date');

  const PickupDay(this.label, this.caption);

  final String label;
  final String caption;
}

/// The surplus listing being built across the three give steps.
///
/// Immutable and passed forward through the router's `extra`, so each screen
/// stays a pure function of the draft handed to it. Phase 5 posts this to the
/// listings API from the Review & publish step.
class SurplusDraft {
  const SurplusDraft({
    this.source,
    this.foodName = '',
    this.foodType,
    this.quantity,
    this.unit = QuantityUnit.mealBoxes,
    this.preparedWhen = PreparedWhen.earlierToday,
    this.safetyConfirmed = false,
    this.photoPath,
    this.pickupDay = PickupDay.today,
    this.customDate,
    this.pickupFrom = const TimeOfDay(hour: 19, minute: 30),
    this.pickupUntil = const TimeOfDay(hour: 20, minute: 30),
    this.pickupLocation = 'Community Hall',
    this.pickupDistanceKm = 1.2,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  final SurplusSource? source;
  final String foodName;
  final FoodType? foodType;
  final int? quantity;
  final QuantityUnit unit;
  final PreparedWhen preparedWhen;

  /// The required "safe and suitable to share" confirmation.
  final bool safetyConfirmed;

  /// Local path to an attached photo. Optional throughout.
  final String? photoPath;

  final PickupDay pickupDay;

  /// Only set when [pickupDay] is [PickupDay.custom].
  final DateTime? customDate;

  final TimeOfDay pickupFrom;
  final TimeOfDay pickupUntil;
  final String pickupLocation;
  final double pickupDistanceKm;

  /// The confirmed pickup point, once the user has chosen one on the map.
  ///
  /// Null means "not chosen yet", and stays null — publishing falls back to
  /// the device's own position, which is also a real reading. Neither path
  /// invents a coordinate, and a listing is never published without one.
  final double? pickupLatitude;
  final double? pickupLongitude;

  /// Whether a point was picked deliberately rather than inherited.
  bool get hasPickupPoint =>
      pickupLatitude != null && pickupLongitude != null;

  SurplusDraft copyWith({
    SurplusSource? source,
    String? foodName,
    FoodType? foodType,
    int? quantity,
    QuantityUnit? unit,
    PreparedWhen? preparedWhen,
    bool? safetyConfirmed,
    String? photoPath,
    PickupDay? pickupDay,
    DateTime? customDate,
    TimeOfDay? pickupFrom,
    TimeOfDay? pickupUntil,
    String? pickupLocation,
    double? pickupDistanceKm,
    double? pickupLatitude,
    double? pickupLongitude,
  }) => SurplusDraft(
    source: source ?? this.source,
    foodName: foodName ?? this.foodName,
    foodType: foodType ?? this.foodType,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    preparedWhen: preparedWhen ?? this.preparedWhen,
    safetyConfirmed: safetyConfirmed ?? this.safetyConfirmed,
    photoPath: photoPath ?? this.photoPath,
    pickupDay: pickupDay ?? this.pickupDay,
    customDate: customDate ?? this.customDate,
    pickupFrom: pickupFrom ?? this.pickupFrom,
    pickupUntil: pickupUntil ?? this.pickupUntil,
    pickupLocation: pickupLocation ?? this.pickupLocation,
    pickupDistanceKm: pickupDistanceKm ?? this.pickupDistanceKm,
    pickupLatitude: pickupLatitude ?? this.pickupLatitude,
    pickupLongitude: pickupLongitude ?? this.pickupLongitude,
  );

  /// Step 1 is answerable once the food is named, counted, categorised and
  /// confirmed safe. The photo stays optional.
  bool get detailsComplete =>
      foodName.trim().isNotEmpty &&
      foodType != null &&
      (quantity ?? 0) > 0 &&
      safetyConfirmed;

  /// "25 Meal Boxes".
  String get quantitySummary => '${quantity ?? 0} ${unit.shortLabel}';

  /// "Vegetarian · Prepared earlier today".
  String get foodSummary {
    final type = foodType?.label ?? '';
    final prepared = preparedWhen.summaryLabel;
    // Sentence-cases the prepared clause when it leads the second half.
    final prep = prepared[0].toUpperCase() + prepared.substring(1);
    return type.isEmpty ? prep : '$type · $prep';
  }

  /// "Approx. 25 hearty servings".
  String get servingsSummary => 'Approx. ${quantity ?? 0} hearty servings';

  /// "Today · 7:30 PM – 8:30 PM".
  String get pickupWindowSummary =>
      '$pickupDayLabel · ${formatTime(pickupFrom)} – ${formatTime(pickupUntil)}';

  /// "Today", "Tomorrow", or the chosen date.
  String get pickupDayLabel {
    if (pickupDay != PickupDay.custom) return pickupDay.label;
    final date = customDate;
    if (date == null) return 'Custom';
    return '${date.day} ${_months[date.month - 1]}';
  }

  /// "1.2 km away".
  String get pickupDistanceLabel =>
      '${pickupDistanceKm.toStringAsFixed(1)} km away';

  /// How long the window is open for, used for the guidance line.
  Duration get pickupWindowLength {
    final from = pickupFrom.hour * 60 + pickupFrom.minute;
    final until = pickupUntil.hour * 60 + pickupUntil.minute;
    // A window crossing midnight wraps rather than going negative.
    final minutes = until >= from ? until - from : (24 * 60) - from + until;
    return Duration(minutes: minutes);
  }

  /// 12-hour clock, e.g. "7:30 PM".
  ///
  /// Written out rather than using `TimeOfDay.format`, which needs a
  /// `BuildContext` and would drag localisation into the model.
  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
