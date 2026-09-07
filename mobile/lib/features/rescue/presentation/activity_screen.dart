import 'package:flutter/material.dart';

import '../../../shared/widgets/consumer_nav_bar.dart';
import '../data/sample_activity.dart';
import '../domain/activity_item.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer Activity Screen".
///
/// Faithful translation of the Stitch design
/// (screen `3e283e153cb14c248d37838d9255e1bb`).
///
/// DIVERGENCE: the design's mock carries a generic top app bar with a back
/// arrow and the title "Item Details" — a leftover from the Stitch template,
/// not this screen. Activity is a bottom-nav destination, so it has no back
/// arrow, and its title comes from the "Activity" heading block below, exactly
/// as Home and Explore do.
///
/// UI only. The feeds come in as parameters and default to the design's
/// fixtures; Phase 5 swaps those defaults for a repository read.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.active = SampleActivity.active,
    this.history = SampleActivity.history,
    this.historyHeading = SampleActivity.historyHeading,
    this.historySummary = SampleActivity.historySummary,
    this.onFilter,
    this.onOpenActivity,
    this.onSelectTab,
  });

  final List<ActivityItem> active;
  final List<ActivityHistoryEntry> history;
  final String historyHeading;
  final String historySummary;

  final VoidCallback? onFilter;
  final void Function(ActivityItem item)? onOpenActivity;
  final void Function(ConsumerTab tab)? onSelectTab;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

enum _ActivityTab { active, history }

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityTab _tab = _ActivityTab.active;

  @override
  Widget build(BuildContext context) {
    final showingActive = _tab == _ActivityTab.active;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      bottomNavigationBar: ConsumerNavBar(
        current: ConsumerTab.activity,
        onSelect: widget.onSelectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _Header(onFilter: widget.onFilter),
                const SizedBox(height: 16),
                _TabSwitcher(
                  tab: _tab,
                  activeCount: widget.active.length,
                  onChanged: (t) => setState(() => _tab = t),
                ),
                const SizedBox(height: 16),
                // The live banner belongs to the Active feed only.
                if (showingActive) ...[
                  const _LiveBanner(),
                  const SizedBox(height: 16),
                  for (final item in widget.active) ...[
                    ActivityCard(
                      item: item,
                      onAction: () => widget.onOpenActivity?.call(item),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _HistoryHint(
                    onSwitch: () => setState(() => _tab = _ActivityTab.history),
                  ),
                ] else
                  _HistoryPanel(
                    heading: widget.historyHeading,
                    summary: widget.historySummary,
                    entries: widget.history,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onFilter});

  final VoidCallback? onFilter;

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
                'Activity',
                style: rescueFont(
                  26,
                  700,
                  color: RescueColors.primary,
                  height: 32 / 26,
                  letterSpacing: -0.02 * 26,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Keep track of your rescues and food shares.',
                style: rescueFont(14, 400, color: RescueColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RescueIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Filter activity',
          onPressed: onFilter,
          color: RescueColors.primary,
          background: _surfaceContainer,
        ),
      ],
    );
  }
}

const Color _surfaceContainer = Color(0xFFEFEEEB);
const Color _surfaceContainerLow = Color(0xFFF4F3F0);
const Color _surfaceContainerHigh = Color(0xFFE9E8E5);
const Color _secondary = Color(0xFF2C694E);
const Color _secondaryContainer = Color(0xFFAEEECB);

/// Full-width Active / History pill switcher.
class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.tab,
    required this.activeCount,
    required this.onChanged,
  });

  final _ActivityTab tab;
  final int activeCount;
  final void Function(_ActivityTab tab) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              label: 'Active',
              badge: '$activeCount',
              selected: tab == _ActivityTab.active,
              onTap: () => onChanged(_ActivityTab.active),
            ),
          ),
          Expanded(
            child: _segment(
              label: 'History',
              selected: tab == _ActivityTab.history,
              onTap: () => onChanged(_ActivityTab.history),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? RescueColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: rescueFont(
                selected ? 17 : 14,
                selected ? 600 : 500,
                color: selected ? Colors.white : RescueColors.muted,
                letterSpacing: selected ? -0.17 : 0,
              ),
            ),
            if (badge != null && selected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: rescueFont(
                    11,
                    700,
                    color: Colors.white,
                    letterSpacing: 0.66,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const LiveDot(size: 10, color: _secondary),
              const SizedBox(width: 8),
              Text(
                'Live activity updated just now',
                style: rescueFont(
                  12,
                  600,
                  color: _secondary,
                  letterSpacing: 0.48,
                ),
              ),
            ],
          ),
          const Icon(Icons.sync_rounded, size: 16, color: _secondary),
        ],
      ),
    );
  }
}

/// One in-flight rescue or share.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.item, this.onAction});

  final ActivityItem item;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final matching = item.status == ActivityStatus.lookingForRescuer;

    return RescueCard(
      radius: 12,
      borderColor: Colors.transparent,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeRow(item: item),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  item.imageAsset,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 76,
                    height: 76,
                    color: _surfaceContainer,
                    child: const Icon(
                      Icons.restaurant_rounded,
                      size: 22,
                      color: RescueColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.kindLabel,
                        style: rescueFont(
                          11,
                          700,
                          color: RescueColors.muted,
                          letterSpacing: 0.66,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(
                        17,
                        600,
                        color: RescueColors.ink,
                        letterSpacing: -0.17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.locationLine != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: RescueColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.locationLine!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: rescueFont(
                                14,
                                400,
                                color: RescueColors.muted,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (item.note != null)
                      Text(
                        item.note!,
                        style: rescueFont(
                          12,
                          500,
                          color: RescueColors.muted,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      matching ? Icons.place_outlined : Icons.schedule_rounded,
                      size: 16,
                      color: RescueColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.detailLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(14, 500, color: RescueColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: item.actionLabel,
                // The share's matching status is a secondary concern; only
                // the rescue gets the filled treatment.
                filled: !matching,
                icon: matching
                    ? Icons.chevron_right_rounded
                    : Icons.arrow_forward,
                onPressed: onAction,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final matching = item.status == ActivityStatus.lookingForRescuer;
    final remaining = item.remainingLabel;

    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: matching ? _surfaceContainerHigh : _secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LiveDot(size: 6, color: _secondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(
                      11,
                      700,
                      color: matching
                          ? RescueColors.primary
                          : const Color(0xFF0E5138),
                      letterSpacing: 0.66,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (remaining != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  matching ? Icons.timelapse_rounded : Icons.timer_outlined,
                  size: 14,
                  color: RescueColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  remaining,
                  style: rescueFont(
                    11,
                    700,
                    color: RescueColors.muted,
                    letterSpacing: 0.66,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final bool filled;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : RescueColors.primary;

    return SizedBox(
      height: 40,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? RescueColors.primary : _surfaceContainer,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: rescueFont(14, 500, color: fg)),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: fg),
          ],
        ),
      ),
    );
  }
}

class _HistoryHint extends StatelessWidget {
  const _HistoryHint({required this.onSwitch});

  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 20,
            color: RescueColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Looking for past rescues?',
              style: rescueFont(14, 400, color: RescueColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSwitch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Switch to History',
                  style: rescueFont(14, 500, color: _secondary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.east_rounded, size: 16, color: _secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.heading,
    required this.summary,
    required this.entries,
  });

  final String heading;
  final String summary;
  final List<ActivityHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 12,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_outlined,
              size: 24,
              color: _secondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            heading,
            style: rescueFont(
              17,
              600,
              color: RescueColors.ink,
              letterSpacing: -0.17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: rescueFont(
              14,
              400,
              color: RescueColors.muted,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in entries) ...[
            _HistoryRow(entry: entry),
            if (entry != entries.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final ActivityHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 20,
            color: _secondary,
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
                  style: rescueFont(14, 500, color: RescueColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(
                    12,
                    500,
                    color: RescueColors.muted,
                    letterSpacing: 0.48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.outcomeLabel,
            style: rescueFont(12, 600, color: _secondary, letterSpacing: 0.48),
          ),
        ],
      ),
    );
  }
}
