import 'package:flutter/material.dart';

import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/surplus_draft.dart';
import 'widgets/give_widgets.dart';

/// "FoodLoop Consumer Surplus Food Details Screen" — step 1 of 3.
///
/// Faithful translation of the Stitch design
/// (screen `c8299f4a379940debf632c160a3602b9`).
///
/// Continue unlocks only once the food is named, categorised, counted and
/// confirmed safe — the design's four required fields. The photo is optional.
class SurplusDetailsScreen extends StatefulWidget {
  const SurplusDetailsScreen({
    super.key,
    required this.draft,
    this.onBack,
    this.onContinue,
  });

  final SurplusDraft draft;
  final VoidCallback? onBack;
  final void Function(SurplusDraft draft)? onContinue;

  @override
  State<SurplusDetailsScreen> createState() => _SurplusDetailsScreenState();
}

class _SurplusDetailsScreenState extends State<SurplusDetailsScreen> {
  late final _name = TextEditingController(text: widget.draft.foodName);
  late final _quantity = TextEditingController(
    text: widget.draft.quantity?.toString() ?? '',
  );

  late SurplusDraft _draft = widget.draft;

  @override
  void initState() {
    super.initState();
    // Keep the draft in step with free-text edits so `detailsComplete`
    // gates the Continue button live.
    _name.addListener(
      () => setState(() => _draft = _draft.copyWith(foodName: _name.text)),
    );
    _quantity.addListener(
      () => setState(
        () => _draft = _draft.copyWith(
          quantity: int.tryParse(_quantity.text) ?? 0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _attachPhoto() {
    // PHASE 5: image_picker. Until then the row is honest about it rather
    // than opening a picker that cannot return anything.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2F312F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
          content: Text(
            'Photo upload is coming soon.',
            style: rescueFont(13, 500, color: const Color(0xFFF2F1EE)),
          ),
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
                  title: 'Food details',
                  stepLabel: '1 of 3',
                  onBack: widget.onBack,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Text(
                        'What food do you have?',
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
                        'Tell us a little about the surplus so we can find '
                        'the right rescue option.',
                        style: rescueFont(
                          14,
                          400,
                          color: RescueColors.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const GiveFieldLabel(
                        label: 'Food name',
                        required: true,
                        hint: 'e.g. Meal boxes, Curries',
                      ),
                      GiveTextField(
                        controller: _name,
                        hintText: 'What are you sharing?',
                      ),
                      const SizedBox(height: 18),

                      const GiveFieldLabel(label: 'Food type', required: true),
                      _FoodTypeGrid(
                        selected: _draft.foodType,
                        onSelect: (type) => setState(
                          () => _draft = _draft.copyWith(foodType: type),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const GiveFieldLabel(
                        label: 'How much food is available?',
                        required: true,
                      ),
                      _QuantityRow(
                        controller: _quantity,
                        unit: _draft.unit,
                        onUnitChanged: (unit) => setState(
                          () => _draft = _draft.copyWith(unit: unit),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'An estimate is okay. Rescuers just need approximate '
                        'counts.',
                        style: rescueFont(12, 400, color: RescueColors.muted),
                      ),
                      const SizedBox(height: 18),

                      const GiveFieldLabel(
                        label: 'When was it prepared?',
                        required: true,
                      ),
                      _PreparedGrid(
                        selected: _draft.preparedWhen,
                        onSelect: (when) => setState(
                          () => _draft = _draft.copyWith(preparedWhen: when),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const GiveFieldLabel(
                        label: 'Food condition',
                        required: true,
                        trailing: GiveBadge(label: 'Required', emphasis: true),
                      ),
                      _SafetyCard(
                        checked: _draft.safetyConfirmed,
                        onChanged: (value) => setState(
                          () =>
                              _draft = _draft.copyWith(safetyConfirmed: value),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const GiveFieldLabel(
                        label: 'Add a photo',
                        trailing: GiveBadge(label: 'Optional'),
                      ),
                      Text(
                        'A clear photo helps rescuers know what to expect.',
                        style: rescueFont(11.5, 400, color: RescueColors.muted),
                      ),
                      const SizedBox(height: 8),
                      _PhotoRow(onTap: _attachPhoto),
                    ],
                  ),
                ),
                GiveActionBar(
                  label: 'Continue',
                  height: 52,
                  onPressed: _draft.detailsComplete
                      ? () => widget.onContinue?.call(_draft)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodTypeGrid extends StatelessWidget {
  const _FoodTypeGrid({required this.selected, required this.onSelect});

  final FoodType? selected;
  final void Function(FoodType type) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final type = FoodType.values[row * 2 + col];
                      return GiveChoiceChip(
                        label: type.label,
                        selected: type == selected,
                        onTap: () => onSelect(type),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
  });

  final TextEditingController controller;
  final QuantityUnit unit;
  final void Function(QuantityUnit unit) onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The design splits this 2:3 across a five-column grid.
        Expanded(
          flex: 2,
          child: GiveTextField(
            controller: controller,
            hintText: 'Qty',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            fontSize: 16,
            fontWeight: 600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: RescueColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RescueColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<QuantityUnit>(
                value: unit,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: RescueColors.muted,
                ),
                style: rescueFont(14.5, 500, color: RescueColors.ink),
                onChanged: (value) {
                  if (value != null) onUnitChanged(value);
                },
                items: [
                  for (final option in QuantityUnit.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(14.5, 500, color: RescueColors.ink),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreparedGrid extends StatelessWidget {
  const _PreparedGrid({required this.selected, required this.onSelect});

  final PreparedWhen selected;
  final void Function(PreparedWhen when) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final when = PreparedWhen.values[row * 2 + col];
                      return GiveChoiceChip(
                        label: when.label,
                        selected: when == selected,
                        onTap: () => onSelect(when),
                        height: 46,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.checked, required this.onChanged});

  final bool checked;
  final void Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked ? RescueColors.primary : RescueColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? RescueColors.primary : RescueColors.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked
                      ? RescueColors.primary
                      : const Color(0xFFB8C9BE),
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safe and suitable to share',
                    style: rescueFont(
                      13.5,
                      600,
                      color: RescueColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'I confirm this food has been stored and handled safely.',
                    style: rescueFont(
                      12,
                      400,
                      color: RescueColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFB8C9BE),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: giveSage,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 21,
                color: RescueColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add food photo',
                    style: rescueFont(
                      13.5,
                      600,
                      color: RescueColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Take photo or upload',
                    style: rescueFont(11, 400, color: RescueColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const GiveBadge(label: 'Optional'),
          ],
        ),
      ),
    );
  }
}
