import 'package:flutter/material.dart';

import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/surplus_draft.dart';
import 'widgets/give_widgets.dart';

/// "FoodLoop Consumer Give Surplus Food Entry Screen".
///
/// Faithful translation of the Stitch design
/// (screen `d61ab0dfa7f8490186c40344bb801985`).
///
/// The way in to the give flow: one question, two answers. Continue stays
/// disabled until a source is picked, then hands the seeded draft to step 1.
class GiveEntryScreen extends StatefulWidget {
  const GiveEntryScreen({
    super.key,
    this.draft = const SurplusDraft(),
    this.onBack,
    this.onContinue,
  });

  final SurplusDraft draft;
  final VoidCallback? onBack;

  /// Receives the draft with its source set.
  final void Function(SurplusDraft draft)? onContinue;

  @override
  State<GiveEntryScreen> createState() => _GiveEntryScreenState();
}

class _GiveEntryScreenState extends State<GiveEntryScreen> {
  late SurplusSource? _source = widget.draft.source;

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
                  title: 'Give surplus food',
                  onBack: widget.onBack,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    children: [
                      Text(
                        'Give surplus food',
                        style: rescueFont(
                          28,
                          700,
                          color: RescueColors.ink,
                          height: 1.2,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Good food shouldn’t go to waste. Tell us what you '
                        'have and we’ll help find it a new destination.',
                        style: rescueFont(
                          14,
                          400,
                          color: RescueColors.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'What are you sharing?',
                        style: rescueFont(
                          17,
                          600,
                          color: RescueColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SourceCard(
                        icon: Icons.soup_kitchen_outlined,
                        title: SurplusSource.home.label,
                        description:
                            'Extra food prepared at home or for a personal '
                            'gathering.',
                        selected: _source == SurplusSource.home,
                        onTap: () =>
                            setState(() => _source = SurplusSource.home),
                      ),
                      const SizedBox(height: 14),
                      _SourceCard(
                        icon: Icons.celebration_outlined,
                        title: SurplusSource.event.label,
                        description:
                            'Surplus from a wedding, function, party, '
                            'catering, or community event.',
                        selected: _source == SurplusSource.event,
                        onTap: () =>
                            setState(() => _source = SurplusSource.event),
                      ),
                      const SizedBox(height: 24),
                      const GiveInfoPanel(
                        message:
                            'FoodLoop will guide you through quantity, '
                            'freshness, pickup timing, and location next.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Share only food that is safe and suitable for others '
                        'to eat.',
                        textAlign: TextAlign.center,
                        style: rescueFont(11.5, 400, color: RescueColors.muted),
                      ),
                    ],
                  ),
                ),
                GiveActionBar(
                  label: 'Continue',
                  height: 56,
                  onPressed: _source == null
                      ? null
                      : () => widget.onContinue?.call(
                          widget.draft.copyWith(source: _source),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two origin choices, behaving as a radio option.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$title. $description',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RescueColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? RescueColors.primary : RescueColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D122019),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: giveSage,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: RescueColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: rescueFont(
                        16,
                        600,
                        color: RescueColors.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: rescueFont(
                        12.5,
                        400,
                        color: RescueColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? RescueColors.primary : RescueColors.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? RescueColors.primary : RescueColors.border,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
