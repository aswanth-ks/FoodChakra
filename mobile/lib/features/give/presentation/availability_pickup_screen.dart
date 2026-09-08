import 'package:flutter/material.dart';

import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/surplus_draft.dart';
import 'widgets/give_widgets.dart';

/// "FoodLoop Consumer Availability & Pickup Screen" — step 2 of 3.
///
/// Faithful translation of the Stitch design
/// (screen `3d47cf51ed654c5aac6fc3c7c884b342`).
///
/// The date chips, the two time controls and the custom-date picker are all
/// live. Choosing a different pickup point needs the Phase 8 map, so those
/// actions stay inert.
class AvailabilityPickupScreen extends StatefulWidget {
  const AvailabilityPickupScreen({
    super.key,
    required this.draft,
    this.onBack,
    this.onContinue,
    this.onChangeLocation,
    this.onUseCurrentLocation,
    this.onChooseOnMap,
  });

  final SurplusDraft draft;
  final VoidCallback? onBack;
  final void Function(SurplusDraft draft)? onContinue;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onUseCurrentLocation;
  final VoidCallback? onChooseOnMap;

  @override
  State<AvailabilityPickupScreen> createState() =>
      _AvailabilityPickupScreenState();
}

class _AvailabilityPickupScreenState extends State<AvailabilityPickupScreen> {
  late SurplusDraft _draft = widget.draft;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _draft.pickupFrom : _draft.pickupUntil,
      helpText: isStart ? 'Pickup opens at' : 'Pickup closes at',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _draft = isStart
          ? _draft.copyWith(pickupFrom: picked)
          : _draft.copyWith(pickupUntil: picked);
    });
  }

  Future<void> _pickDay(PickupDay day) async {
    if (day != PickupDay.custom) {
      setState(() => _draft = _draft.copyWith(pickupDay: day));
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.customDate ?? now.add(const Duration(days: 2)),
      firstDate: now,
      // Surplus food is not useful far out; a fortnight is generous.
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'Pickup date',
    );
    if (picked == null || !mounted) return;

    setState(
      () => _draft = _draft.copyWith(
        pickupDay: PickupDay.custom,
        customDate: picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                GiveStepAppBar(
                  title: 'Availability & pickup',
                  stepLabel: '2 of 3',
                  onBack: widget.onBack,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Text(
                        'When can someone collect it?',
                        style: rescueFont(
                          27,
                          700,
                          color: RescueColors.ink,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set a pickup window that gives rescuers enough time '
                        'to collect the food safely.',
                        style: rescueFont(
                          14,
                          400,
                          color: RescueColors.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pickup date',
                            style: rescueFont(15, 600, color: RescueColors.ink),
                          ),
                          Text(
                            'Step 1 of 2',
                            style: rescueFont(
                              12,
                              500,
                              color: RescueColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DayRow(
                        selected: _draft.pickupDay,
                        customLabel: _draft.pickupDayLabel,
                        onSelect: _pickDay,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Pickup window',
                        style: rescueFont(15, 600, color: RescueColors.ink),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeCard(
                              caption: 'From',
                              time: _draft.pickupFrom,
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeCard(
                              caption: 'Until',
                              time: _draft.pickupUntil,
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_draft.pickupWindowLength.inMinutes}-minute '
                        'collection window. Give rescuers enough time to '
                        'collect the food safely.',
                        style: rescueFont(
                          12,
                          400,
                          color: RescueColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 26),

                      Text(
                        'Where can they collect it?',
                        style: rescueFont(
                          17,
                          700,
                          color: RescueColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a nearby pickup point. Your exact location is '
                        'shared only when needed for the rescue.',
                        style: rescueFont(
                          13,
                          400,
                          color: RescueColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LocationCard(
                        name: _draft.pickupLocation,
                        distanceLabel: _draft.pickupDistanceLabel,
                        onChange: widget.onChangeLocation,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _LocationAction(
                              icon: Icons.my_location_rounded,
                              label: 'Current location',
                              onTap: widget.onUseCurrentLocation,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _LocationAction(
                              icon: Icons.map_outlined,
                              label: 'Choose on map',
                              onTap: widget.onChooseOnMap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your pickup location is shared with the matched '
                        'rescuer for collection.',
                        style: rescueFont(
                          11,
                          400,
                          color: RescueColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GiveActionBar(
                  label: 'Continue',
                  onPressed: () => widget.onContinue?.call(_draft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.selected,
    required this.customLabel,
    required this.onSelect,
  });

  final PickupDay selected;

  /// Shows the chosen date once a custom one is set.
  final String customLabel;

  final void Function(PickupDay day) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in PickupDay.values) ...[
          if (day != PickupDay.today) const SizedBox(width: 10),
          Expanded(
            child: _DayCard(
              label: day == PickupDay.custom && selected == PickupDay.custom
                  ? customLabel
                  : day.label,
              caption: day.caption,
              selected: day == selected,
              onTap: () => onSelect(day),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? giveSage : RescueColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? RescueColors.primary : RescueColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: rescueFont(
                  14,
                  selected ? 700 : 600,
                  color: selected ? RescueColors.primary : RescueColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: rescueFont(
                  11,
                  selected ? 500 : 400,
                  color: RescueColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.caption,
    required this.time,
    required this.onTap,
  });

  final String caption;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RescueColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caption.toUpperCase(),
              style: rescueFont(
                11,
                700,
                color: RescueColors.muted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    SurplusDraft.formatTime(time),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(
                      19,
                      700,
                      color: RescueColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: giveSage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Set',
                    style: rescueFont(11, 500, color: RescueColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.name,
    required this.distanceLabel,
    this.onChange,
  });

  final String name;
  final String distanceLabel;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChange,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: RescueColors.primary.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: giveSage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: RescueColors.primary.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 21,
                color: RescueColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: rescueFont(15, 700, color: RescueColors.ink),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: RescueColors.live,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Near your current location · $distanceLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(12, 400, color: RescueColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Change',
              style: rescueFont(13, 600, color: RescueColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationAction extends StatelessWidget {
  const _LocationAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RescueColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: RescueColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: rescueFont(12, 600, color: RescueColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
