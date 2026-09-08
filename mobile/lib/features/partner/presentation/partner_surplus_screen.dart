import 'package:flutter/material.dart';

import '../../../shared/widgets/partner_nav_bar.dart';
import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/partner_dashboard.dart';
import 'widgets/partner_widgets.dart';

/// "FoodLoop Restaurant Partner Surplus Management Screen".
///
/// Faithful translation of the Stitch design
/// (screen `1dfcc1f17d784472998243e653639be0`).
///
/// Everything the partner has shared, split into Active, Drafts and History.
///
/// **Design divergence:** the design draws only the Active list, while
/// showing a Drafts count of 1 and a History tab. Rather than leave two tabs
/// dead, both render the same card against fixture entries; the empty state
/// is what shows once a list really is empty.
class PartnerSurplusScreen extends StatefulWidget {
  const PartnerSurplusScreen({
    super.key,
    required this.dashboard,
    this.onBack,
    this.onAddSurplus,
    this.onOpenSurplus,
    this.onManageSurplus,
    this.onSelectTab,
  });

  final PartnerDashboard dashboard;

  final VoidCallback? onBack;
  final VoidCallback? onAddSurplus;

  /// The card's primary action: View rescue / View status.
  final void Function(PartnerSurplus surplus)? onOpenSurplus;

  /// The card's secondary "Manage" action.
  final void Function(PartnerSurplus surplus)? onManageSurplus;

  final void Function(PartnerTab tab)? onSelectTab;

  @override
  State<PartnerSurplusScreen> createState() => _PartnerSurplusScreenState();
}

class _PartnerSurplusScreenState extends State<PartnerSurplusScreen> {
  PartnerSurplusTab _tab = PartnerSurplusTab.active;

  @override
  Widget build(BuildContext context) {
    final dashboard = widget.dashboard;
    final items = dashboard.surplusFor(_tab);

    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _SurplusAppBar(
                  onBack: widget.onBack,
                  onAdd: widget.onAddSurplus,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Text(
                        'Your surplus',
                        style: rescueFont(
                          24,
                          800,
                          color: RescueColors.ink,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage food you’ve shared with FoodLoop.',
                        style: rescueFont(13, 500, color: RescueColors.muted),
                      ),
                      const SizedBox(height: 16),
                      _TabBar(
                        current: _tab,
                        counts: {
                          for (final tab in PartnerSurplusTab.values)
                            tab: dashboard.surplusFor(tab).length,
                        },
                        onSelect: (tab) => setState(() => _tab = tab),
                      ),
                      const SizedBox(height: 18),
                      _ListHeader(tab: _tab, count: items.length),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        _EmptyState(tab: _tab, onAdd: widget.onAddSurplus)
                      else
                        for (final surplus in items) ...[
                          PartnerSurplusCard(
                            surplus: surplus,
                            onOpen: () => widget.onOpenSurplus?.call(surplus),
                            onManage: () =>
                                widget.onManageSurplus?.call(surplus),
                          ),
                          const SizedBox(height: 14),
                        ],
                      const SizedBox(height: 8),
                      const _DispatchNotice(),
                    ],
                  ),
                ),
                PartnerNavBar(
                  current: PartnerTab.surplus,
                  onSelect: widget.onSelectTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back, the "Surplus" title with its live dot, and the quick-add button.
class _SurplusAppBar extends StatelessWidget {
  const _SurplusAppBar({this.onBack, this.onAdd});

  final VoidCallback? onBack;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEFEDE7))),
      ),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Go back',
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
          Text(
            'Surplus',
            style: rescueFont(
              16,
              700,
              color: RescueColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 6),
          const LiveDot(color: partnerEmerald, size: 7),
          const Spacer(),
          _RoundButton(
            icon: Icons.add_rounded,
            tooltip: 'Add surplus food',
            onPressed: onAdd,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: filled ? RescueColors.primary : RescueColors.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? RescueColors.primary : RescueColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : RescueColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Active / Drafts / History, with the design's counter pills.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.current,
    required this.counts,
    required this.onSelect,
  });

  final PartnerSurplusTab current;
  final Map<PartnerSurplusTab, int> counts;
  final void Function(PartnerSurplusTab tab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Row(
        children: [
          for (final tab in PartnerSurplusTab.values)
            Expanded(
              child: _TabButton(
                tab: tab,
                // History is a closed list, so the design gives it no counter.
                count: tab == PartnerSurplusTab.history ? null : counts[tab],
                selected: tab == current,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final PartnerSurplusTab tab;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? RescueColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: rescueFont(
                13,
                selected ? 700 : 600,
                color: selected ? Colors.white : RescueColors.muted,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : RescueColors.sage,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: rescueFont(
                    10,
                    800,
                    color: selected ? Colors.white : RescueColors.primary,
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

/// "2 ACTIVE LISTINGS · Live opportunities" with the auto-sync note.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.tab, required this.count});

  final PartnerSurplusTab tab;
  final int count;

  @override
  Widget build(BuildContext context) {
    final noun = switch (tab) {
      PartnerSurplusTab.active =>
        count == 1 ? 'ACTIVE LISTING' : 'ACTIVE LISTINGS',
      PartnerSurplusTab.drafts => count == 1 ? 'DRAFT' : 'DRAFTS',
      PartnerSurplusTab.history =>
        count == 1 ? 'PAST LISTING' : 'PAST LISTINGS',
    };
    final caption = switch (tab) {
      PartnerSurplusTab.active => 'Live opportunities',
      PartnerSurplusTab.drafts => 'Not published yet',
      PartnerSurplusTab.history => 'Closed',
    };

    return Row(
      children: [
        Flexible(
          child: Text(
            '$count $noun',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(
              12,
              700,
              color: RescueColors.ink,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '· $caption',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(12, 400, color: RescueColors.muted),
          ),
        ),
        const Spacer(),
        if (tab == PartnerSurplusTab.active) ...[
          const Icon(Icons.sync_rounded, size: 12, color: RescueColors.primary),
          const SizedBox(width: 4),
          Text(
            'Auto-syncing',
            style: rescueFont(11, 600, color: RescueColors.primary),
          ),
        ],
      ],
    );
  }
}

/// Shown when a tab genuinely has nothing in it.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab, this.onAdd});

  final PartnerSurplusTab tab;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final message = switch (tab) {
      PartnerSurplusTab.active => 'Nothing is live right now.',
      PartnerSurplusTab.drafts => 'No saved drafts.',
      PartnerSurplusTab.history => 'No past listings yet.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: RescueColors.sageSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: RescueColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(message, style: rescueFont(13.5, 600, color: RescueColors.ink)),
          if (tab == PartnerSurplusTab.active) ...[
            const SizedBox(height: 4),
            Text(
              'Share surplus from your kitchen to get started.',
              textAlign: TextAlign.center,
              style: rescueFont(12, 400, color: RescueColors.muted),
            ),
            const SizedBox(height: 14),
            RescueMiniButton(label: 'Add surplus food', onPressed: onAdd),
          ],
        ],
      ),
    );
  }
}

/// Standing reminder to kitchen staff about the handover.
class _DispatchNotice extends StatelessWidget {
  const _DispatchNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.sageSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.sage),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: RescueColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.room_service_outlined,
              size: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen Dispatch Notice',
                  style: rescueFont(12, 700, color: RescueColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep boxed items ready at the designated counter. '
                  'Remember to verify the rescuer’s pickup code before '
                  'handoff.',
                  style: rescueFont(
                    12,
                    400,
                    color: RescueColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
