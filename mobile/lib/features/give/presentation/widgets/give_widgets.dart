import 'package:flutter/material.dart';

import '../../../rescue/presentation/widgets/rescue_widgets.dart';

/// Shared chrome for the three-step give-surplus flow.
///
/// The give designs use the same brand scale as the consumer rescue designs,
/// so [RescueColors] and [rescueFont] carry over; only the handful of tones
/// specific to these screens are defined here.

/// Sage fill behind the step badge, selected chips and icon tiles.
const Color giveSage = Color(0xFFEAF1EC);

/// Border on selected surfaces and the sage-tinted info panels.
const Color giveSageBorder = Color(0xFFD8E5DC);

/// The disabled Continue button's fill and label.
const Color giveDisabledFill = Color(0xFFD9DEDB);
const Color giveDisabledText = Color(0xFF7D8E84);

/// Placeholder text inside the form fields.
const Color givePlaceholder = Color(0xFF94A399);

/// Header shared by the three form steps: back, title, and a step badge.
class GiveStepAppBar extends StatelessWidget {
  const GiveStepAppBar({
    super.key,
    required this.title,
    this.stepLabel,
    this.onBack,
  });

  final String title;

  /// "1 of 3". Absent on the entry screen, which precedes the steps.
  final String? stepLabel;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEECE7))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          RescueIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Go back',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: rescueFont(
                15.5,
                600,
                color: RescueColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Balances the back button so the title stays centred.
          SizedBox(
            width: 56,
            child: stepLabel == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: giveSage,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: giveSageBorder),
                      ),
                      child: Text(
                        stepLabel!,
                        style: rescueFont(
                          11,
                          600,
                          color: RescueColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase field label, with the design's green required asterisk and an
/// optional trailing hint or badge.
class GiveFieldLabel extends StatelessWidget {
  const GiveFieldLabel({
    super.key,
    required this.label,
    this.required = false,
    this.hint,
    this.trailing,
  });

  final String label;
  final bool required;

  /// Right-aligned grey hint, e.g. "e.g. Meal boxes, Curries".
  final String? hint;

  /// Overrides [hint] when a chip is wanted instead.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label.toUpperCase(),
                style: rescueFont(
                  12.5,
                  600,
                  color: RescueColors.ink,
                  letterSpacing: 0.8,
                ),
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: rescueFont(12.5, 600, color: RescueColors.primary),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (hint != null)
            Text(hint!, style: rescueFont(11, 400, color: RescueColors.muted)),
        ],
      ),
    );
  }
}

/// Small pill used for "Required" and "Optional" markers.
class GiveBadge extends StatelessWidget {
  const GiveBadge({super.key, required this.label, this.emphasis = false});

  final String label;

  /// Sage-on-green for "Required"; neutral grey otherwise.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasis ? giveSage : const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: rescueFont(
          10.5,
          600,
          color: emphasis ? RescueColors.primary : RescueColors.muted,
        ),
      ),
    );
  }
}

/// The flow's text input, matching the design's 50px rounded field.
class GiveTextField extends StatelessWidget {
  const GiveTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.fontSize = 15,
    this.fontWeight = 500,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final double fontSize;
  final int fontWeight;
  final void Function(String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: textAlign,
        onChanged: onChanged,
        cursorColor: RescueColors.primary,
        style: rescueFont(fontSize, fontWeight, color: RescueColors.ink),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: rescueFont(fontSize, 400, color: givePlaceholder),
          filled: true,
          fillColor: RescueColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: _border(RescueColors.border),
          enabledBorder: _border(RescueColors.border),
          focusedBorder: _border(RescueColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Selectable pill used for the food-type and preparation-time grids.
class GiveChoiceChip extends StatelessWidget {
  const GiveChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 42,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? giveSage : RescueColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? RescueColors.primary : RescueColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: rescueFont(
            13.5,
            selected ? 600 : 500,
            color: selected ? RescueColors.primary : RescueColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Sage-tinted guidance panel, e.g. "FoodLoop will guide you through…".
class GiveInfoPanel extends StatelessWidget {
  const GiveInfoPanel({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7DE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: RescueColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: RescueColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: rescueFont(
                12.5,
                500,
                color: const Color(0xFF243B2F),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky footer holding the flow's Continue action and the gesture bar.
class GiveActionBar extends StatelessWidget {
  const GiveActionBar({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.height = 54,
  });

  final String label;

  /// Null renders the design's explicit disabled treatment rather than a
  /// dimmed primary button.
  final VoidCallback? onPressed;

  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEEECE7))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: RescueColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: giveDisabledFill,
                    disabledForegroundColor: giveDisabledText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: rescueFont(
                          15,
                          600,
                          color: enabled ? Colors.white : giveDisabledText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const HomeIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
