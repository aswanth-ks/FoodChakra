import 'package:flutter/material.dart';

import '../../../shared/widgets/partner_nav_bar.dart';
import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/partner_dashboard.dart';
import 'widgets/partner_widgets.dart';

/// "FoodLoop Restaurant Partner Home Screen".
///
/// Faithful translation of the Stitch design
/// (screen `a28e2ad4001447d19e06b3f8c70a2f02`).
///
/// The operational dashboard a partner lands on after signing in: today's
/// numbers, the one big "Add surplus food" action, anything approaching its
/// pickup window, and what is currently live.
class PartnerHomeScreen extends StatelessWidget {
  const PartnerHomeScreen({
    super.key,
    required this.dashboard,
    this.onAddSurplus,
    this.onNotifications,
    this.onViewPickupAlert,
    this.onOpenSurplus,
    this.onViewAllSurplus,
    this.onViewActivity,
    this.onRescueHistory,
    this.onSelectTab,
  });

  final PartnerDashboard dashboard;

  final VoidCallback? onAddSurplus;
  final VoidCallback? onNotifications;

  /// The amber banner's "View", and the "Pickup soon" metric.
  final VoidCallback? onViewPickupAlert;

  final void Function(PartnerSurplus surplus)? onOpenSurplus;
  final VoidCallback? onViewAllSurplus;
  final VoidCallback? onViewActivity;
  final VoidCallback? onRescueHistory;
  final void Function(PartnerTab tab)? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final profile = dashboard.profile;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _PartnerHeader(
                  profile: profile,
                  onNotifications: onNotifications,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _Greeting(dashboard: dashboard),
                      const SizedBox(height: 16),
                      _OverviewSection(dashboard: dashboard),
                      const SizedBox(height: 16),
                      _AddSurplusAction(onPressed: onAddSurplus),
                      const SizedBox(height: 16),
                      _PickupAlert(
                        dashboard: dashboard,
                        onView: onViewPickupAlert,
                      ),
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: 'Active surplus',
                        actionLabel: 'View all',
                        onAction: onViewAllSurplus,
                        badgeCount: dashboard.activeSurplus.length,
                      ),
                      const SizedBox(height: 10),
                      for (final surplus in dashboard.activeSurplus) ...[
                        surplus.isPrimary
                            ? _PrimarySurplusCard(
                                surplus: surplus,
                                onOpen: () => onOpenSurplus?.call(surplus),
                              )
                            : _CompactSurplusCard(
                                surplus: surplus,
                                onOpen: () => onOpenSurplus?.call(surplus),
                              ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 2),
                      _TodaysImpactCard(dashboard: dashboard),
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: 'Recent activity',
                        actionLabel: 'View activity',
                        onAction: onViewActivity,
                      ),
                      const SizedBox(height: 10),
                      _RecentActivityCard(rows: dashboard.recentActivity),
                      const SizedBox(height: 16),
                      _QuickActions(
                        onAllSurplus: onViewAllSurplus,
                        onRescueHistory: onRescueHistory,
                      ),
                    ],
                  ),
                ),
                PartnerNavBar(current: PartnerTab.home, onSelect: onSelectTab),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Business mark, name, category and the notification bell.
class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.profile, this.onNotifications});

  final PartnerProfile profile;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEFEDE7))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: RescueColors.primary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RescueColors.sage, width: 2),
            ),
            child: const Icon(Icons.eco_rounded, size: 20, color: Colors.white),
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
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          15,
                          700,
                          color: RescueColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (profile.isOpen) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: partnerEmerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  profile.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(11.5, 500, color: RescueColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BellButton(onPressed: onNotifications),
        ],
      ),
    );
  }
}

/// Notification bell with the design's unread dot.
class _BellButton extends StatelessWidget {
  const _BellButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Operational notifications, unread',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: RescueColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RescueColors.border),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: RescueColors.ink,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: partnerEmerald,
                    shape: BoxShape.circle,
                    border: Border.all(color: RescueColors.card, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Good evening, Green Leaf Kitchen 👋".
class _Greeting extends StatelessWidget {
  const _Greeting({required this.dashboard});

  final PartnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${dashboard.greeting(DateTime.now())}, '
          '${dashboard.profile.name} 👋',
          style: rescueFont(
            23,
            700,
            color: RescueColors.ink,
            height: 1.3,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Here’s what’s happening with your surplus today.',
          style: rescueFont(13, 400, color: RescueColors.muted),
        ),
      ],
    );
  }
}

/// "Today's overview" heading plus the three metric cards.
class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.dashboard});

  final PartnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'TODAY’S OVERVIEW',
                style: rescueFont(
                  12,
                  600,
                  color: RescueColors.muted,
                  letterSpacing: 1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: partnerEmeraldBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: partnerEmeraldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LiveDot(color: partnerEmerald, size: 6),
                  const SizedBox(width: 5),
                  Text(
                    'Live kitchen sync',
                    style: rescueFont(11, 500, color: const Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // IntrinsicHeight rather than stretch: these sit in an unbounded
        // ListView, where a stretched Row has no height to stretch to.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricCard(
                  value: '${dashboard.portionsShared}',
                  label: 'Portions shared',
                  caption: dashboard.batchLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: '${dashboard.activeRescues}',
                  label: 'Active rescues',
                  caption: dashboard.matchedLabel,
                  captionColor: partnerEmerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: '${dashboard.pickupSoonCount}',
                  label: 'Pickup soon',
                  caption: dashboard.pickupSoonLabel,
                  valueColor: partnerAmber,
                  captionColor: partnerAmber,
                  urgent: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the three "Today's overview" tiles.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.caption,
    this.valueColor = RescueColors.primary,
    this.captionColor = RescueColors.muted,
    this.urgent = false,
  });

  final String value;
  final String label;
  final String caption;
  final Color valueColor;
  final Color captionColor;

  /// The amber treatment the design gives the "Pickup soon" tile.
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: urgent ? partnerAmberBg : RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent ? partnerAmberBorder : RescueColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: rescueFont(
              23,
              800,
              color: valueColor,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: rescueFont(11.5, 500, color: RescueColors.ink, height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(caption, style: rescueFont(10, 500, color: captionColor)),
        ],
      ),
    );
  }
}

/// The screen's dominant CTA.
class _AddSurplusAction extends StatelessWidget {
  const _AddSurplusAction({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 54,
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: RescueColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, size: 16),
                ),
                const SizedBox(width: 10),
                Text('Add surplus food', style: rescueFont(15, 600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Share surplus from your kitchen before it goes to waste.',
          textAlign: TextAlign.center,
          style: rescueFont(11, 400, color: RescueColors.muted),
        ),
      ],
    );
  }
}

/// Amber banner for the batch closest to its pickup window.
class _PickupAlert extends StatelessWidget {
  const _PickupAlert({required this.dashboard, this.onView});

  final PartnerDashboard dashboard;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: partnerAmberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: partnerAmberBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: partnerAmberTile,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: partnerAmberBorder),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 16,
              color: partnerAmberDeep,
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
                        dashboard.pickupAlertTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          13,
                          700,
                          color: partnerAmberDeep,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const LiveDot(color: partnerAmber, size: 6),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dashboard.pickupSoonDetail,
                  style: rescueFont(
                    12,
                    500,
                    color: const Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onView,
            style: FilledButton.styleFrom(
              backgroundColor: partnerAmberDeep,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View', style: rescueFont(12, 600)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The full card the design gives a batch with a rescuer already matched.
class _PrimarySurplusCard extends StatelessWidget {
  const _PrimarySurplusCard({required this.surplus, this.onOpen});

  final PartnerSurplus surplus;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A122019),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartnerThumbnail(
                asset: surplus.imageAsset,
                size: 84,
                showLive: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            surplus.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rescueFont(
                              15,
                              700,
                              color: RescueColors.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: partnerEmeraldBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: partnerEmeraldBorder),
                          ),
                          child: Text(
                            surplus.status.label,
                            style: rescueFont(
                              10.5,
                              700,
                              color: const Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (surplus.detailLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        surplus.detailLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(12, 400, color: RescueColors.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const RescueDivider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: RescueColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            surplus.windowLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rescueFont(
                              11.5,
                              500,
                              color: RescueColors.ink,
                            ),
                          ),
                        ),
                        if (surplus.countdownLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: partnerAmberBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              surplus.countdownLabel!,
                              style: rescueFont(11.5, 600, color: partnerAmber),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const RescueDivider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 13,
                color: RescueColors.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  surplus.locationLine ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(11.5, 400, color: RescueColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: RescueColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(surplus.actionLabel, style: rescueFont(12, 600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The compact row the design gives a batch still looking for a rescuer.
class _CompactSurplusCard extends StatelessWidget {
  const _CompactSurplusCard({required this.surplus, this.onOpen});

  final PartnerSurplus surplus;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Row(
        children: [
          PartnerThumbnail(asset: surplus.imageAsset, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surplus.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(
                    14,
                    700,
                    color: RescueColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      surplus.windowLabel,
                      style: rescueFont(11.5, 400, color: RescueColors.muted),
                    ),
                    Text(
                      '  ·  ',
                      style: rescueFont(11.5, 400, color: RescueColors.muted),
                    ),
                    Flexible(
                      child: Text(
                        surplus.status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          11.5,
                          500,
                          color: RescueColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: RescueColors.sageSubtle,
              foregroundColor: RescueColors.ink,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(color: RescueColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  surplus.actionLabel,
                  style: rescueFont(11.5, 600, color: RescueColors.ink),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: RescueColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three divided figures summarising the day.
class _TodaysImpactCard extends StatelessWidget {
  const _TodaysImpactCard({required this.dashboard});

  final PartnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today’s impact',
                  style: rescueFont(
                    13,
                    700,
                    color: RescueColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                'Kitchen metrics',
                style: rescueFont(11, 500, color: RescueColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ImpactFigure(
                    value: '${dashboard.portionsShared}',
                    label: 'Portions shared',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: RescueColors.border,
                ),
                Expanded(
                  child: _ImpactFigure(
                    value: '${dashboard.rescuesComplete}',
                    label: 'Rescues complete',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: RescueColors.border,
                ),
                Expanded(
                  child: _ImpactFigure(
                    value: dashboard.completionRateLabel,
                    label: 'Completion rate',
                    valueColor: partnerEmerald,
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

class _ImpactFigure extends StatelessWidget {
  const _ImpactFigure({
    required this.value,
    required this.label,
    this.valueColor = RescueColors.primary,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: rescueFont(19, 800, color: valueColor, letterSpacing: -0.4),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: rescueFont(10.5, 500, color: RescueColors.muted),
        ),
      ],
    );
  }
}

/// Two compact rows of what just happened.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.rows});

  final List<PartnerActivityRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const RescueDivider(),
            _ActivityRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.row});

  final PartnerActivityRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: row.completed ? partnerEmeraldBg : RescueColors.sage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: row.completed
                    ? partnerEmeraldBorder
                    : RescueColors.border,
              ),
            ),
            child: Icon(
              row.completed ? Icons.check_rounded : Icons.upload_rounded,
              size: 14,
              color: row.completed ? partnerEmerald : RescueColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(12.5, 700, color: RescueColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  row.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(11, 400, color: RescueColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: row.completed ? partnerEmeraldBg : RescueColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: row.completed
                    ? partnerEmeraldBorder
                    : RescueColors.border,
              ),
            ),
            child: Text(
              row.badgeLabel,
              style: rescueFont(
                11,
                600,
                color: row.completed
                    ? const Color(0xFF065F46)
                    : RescueColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two shortcuts at the foot of the dashboard.
class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onAllSurplus, this.onRescueHistory});

  final VoidCallback? onAllSurplus;
  final VoidCallback? onRescueHistory;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.inventory_2_outlined,
              title: 'All surplus',
              caption: 'Active & drafts',
              onTap: onAllSurplus,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.show_chart_rounded,
              title: 'Rescue history',
              caption: 'Full logs',
              onTap: onRescueHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: RescueColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RescueColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: RescueColors.sage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: RescueColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(12, 700, color: RescueColors.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(10, 400, color: RescueColors.muted),
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
