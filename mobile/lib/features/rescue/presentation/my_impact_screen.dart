import 'package:flutter/material.dart';

import '../../../shared/widgets/consumer_nav_bar.dart';
import '../data/sample_impact.dart';
import '../domain/impact_summary.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer My Impact Screen".
///
/// Faithful translation of the Stitch design
/// (screen `193a47c489864bfca7fce11800f7ce35`).
///
/// Reachable two ways — the Impact nav tab, and "View impact" on Home — so the
/// header's back arrow is rendered only when there is something to pop.
///
/// UI only. The figures come in as parameters and default to the design's
/// fixtures; Phase 5 computes them from the rescue history.
class MyImpactScreen extends StatefulWidget {
  const MyImpactScreen({
    super.key,
    this.summary = SampleImpact.summary,
    this.recent = SampleImpact.recent,
    this.onBack,
    this.onAboutMethodology,
    this.onViewAll,
    this.onSelectTab,
  });

  final ImpactSummary summary;
  final List<ImpactEntry> recent;

  /// Null when the screen is the nav-tab root, which has nothing to pop.
  final VoidCallback? onBack;

  final VoidCallback? onAboutMethodology;
  final VoidCallback? onViewAll;
  final void Function(ConsumerTab tab)? onSelectTab;

  @override
  State<MyImpactScreen> createState() => _MyImpactScreenState();
}

class _MyImpactScreenState extends State<MyImpactScreen> {
  late String _range = widget.summary.rangeLabel;

  Future<void> _pickRange() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RescueColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final range in SampleImpact.ranges)
              ListTile(
                title: Text(
                  range,
                  style: rescueFont(
                    14.5,
                    range == _range ? 600 : 400,
                    color: range == _range
                        ? RescueColors.primary
                        : RescueColors.ink,
                  ),
                ),
                trailing: range == _range
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: RescueColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(range),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null && mounted) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RescueColors.surface,
      bottomNavigationBar: ConsumerNavBar(
        current: ConsumerTab.impact,
        onSelect: widget.onSelectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _ImpactAppBar(
                  onBack: widget.onBack,
                  onInfo: widget.onAboutMethodology,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      _TitleRow(range: _range, onPickRange: _pickRange),
                      const SizedBox(height: 24),
                      _PrimaryImpactCard(summary: widget.summary),
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: 'Recent activity',
                        actionLabel: 'View all  →',
                        onAction: widget.onViewAll,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < widget.recent.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _ImpactEntryRow(entry: widget.recent[i]),
                      ],
                      const SizedBox(height: 24),
                      const _AffirmationNote(),
                    ],
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

const Color _sageBorder = Color(0xFFD8E6DF);
const Color _subtle = Color(0xFF88988E);

class _ImpactAppBar extends StatelessWidget {
  const _ImpactAppBar({this.onBack, this.onInfo});

  final VoidCallback? onBack;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RescueColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (onBack != null)
            RescueIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back',
              onPressed: onBack,
            )
          else
            // Keeps the title centred when arrived at via the nav tab.
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              'My impact',
              textAlign: TextAlign.center,
              style: rescueFont(
                16,
                600,
                color: RescueColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          RescueIconButton(
            icon: Icons.info_outline_rounded,
            tooltip: 'About how impact is measured',
            onPressed: onInfo,
            color: RescueColors.muted,
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.range, required this.onPickRange});

  final String range;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your impact',
                style: rescueFont(
                  27,
                  700,
                  color: RescueColors.ink,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Every rescue and share adds up.',
                style: rescueFont(
                  14,
                  400,
                  color: RescueColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RangePill(range: range, onTap: onPickRange),
      ],
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.range, required this.onTap});

  final String range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: RescueColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: RescueColors.muted,
            ),
            const SizedBox(width: 6),
            Text(range, style: rescueFont(13, 600, color: RescueColors.ink)),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: RescueColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero total, supporting line and the three factual counts.
class _PrimaryImpactCard extends StatelessWidget {
  const _PrimaryImpactCard({required this.summary});

  final ImpactSummary summary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Watermarked sage arc bleeding off the top-right corner.
          Positioned(
            right: -32,
            top: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: RescueColors.sageSubtle.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          RescueCard(
            radius: 16,
            color: Colors.transparent,
            padding: const EdgeInsets.all(20),
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: RescueColors.sageSubtle,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _sageBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: RescueColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CUMULATIVE TOTAL',
                              style: rescueFont(
                                11,
                                700,
                                color: RescueColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      summary.lastUpdatedLabel,
                      style: rescueFont(12, 500, color: _subtle),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${summary.mealBoxes}',
                      style: rescueFont(
                        38,
                        800,
                        color: RescueColors.primary,
                        height: 1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'meal boxes rescued',
                        style: rescueFont(17, 600, color: RescueColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: RescueColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        summary.rescuesLabel,
                        style: rescueFont(13.5, 500, color: RescueColors.muted),
                      ),
                    ),
                  ],
                ),
                const RescueDivider(vertical: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CountTile(
                        value: '${summary.servings}',
                        label: 'Servings',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CountTile(
                        value: '${summary.rescues}',
                        label: 'Rescues',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CountTile(
                        value: '${summary.shares}',
                        label: 'Food shares',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: RescueColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: rescueFont(22, 700, color: RescueColors.ink, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(12, 500, color: RescueColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ImpactEntryRow extends StatelessWidget {
  const _ImpactEntryRow({required this.entry});

  final ImpactEntry entry;

  @override
  Widget build(BuildContext context) {
    final rescued = entry.kind == ImpactEntryKind.rescued;

    return RescueCard(
      radius: 12,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconTile(
            icon: rescued ? Icons.inventory_2_outlined : Icons.upload_outlined,
            size: 44,
            iconSize: 20,
            background: RescueColors.sageSubtle,
            borderColor: _sageBorder,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(
                    14.5,
                    600,
                    color: RescueColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        // Shares get the lighter green, so kind is readable
                        // without relying on the label alone.
                        color: rescued
                            ? RescueColors.primary
                            : const Color(0xFF3A7D5C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${entry.kindLabel}  ·  ${entry.whenLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(12, 400, color: RescueColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: RescueColors.sageSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _sageBorder),
            ),
            child: Text(
              '${entry.outcomeLabel} ✓',
              style: rescueFont(12, 600, color: RescueColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AffirmationNote extends StatelessWidget {
  const _AffirmationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.sageSubtle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sageBorder),
      ),
      child: Text(
        'Good food stayed in circulation.',
        textAlign: TextAlign.center,
        style: rescueFont(13, 500, color: RescueColors.muted),
      ),
    );
  }
}
