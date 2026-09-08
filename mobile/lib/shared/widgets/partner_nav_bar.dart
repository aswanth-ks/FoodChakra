import 'package:flutter/material.dart';

import '../../features/rescue/presentation/widgets/rescue_widgets.dart';

/// The five restaurant-partner tabs. Ordered as they appear in the designs.
///
/// Deliberately separate from `ConsumerTab`: the two apps share a brand but
/// not a destination list, and a partner never sees Explore.
enum PartnerTab {
  home('Home', Icons.home_rounded, Icons.home_outlined),
  surplus('Surplus', Icons.inventory_2_rounded, Icons.inventory_2_outlined),
  activity(
    'Activity',
    Icons.monitor_heart_rounded,
    Icons.monitor_heart_outlined,
  ),
  impact('Impact', Icons.insights_rounded, Icons.insights_outlined),
  profile('Profile', Icons.store_rounded, Icons.storefront_outlined);

  const PartnerTab(this.label, this.activeIcon, this.icon);

  final String label;
  final IconData activeIcon;
  final IconData icon;
}

/// Fixed bottom navigation shared by every partner tab screen.
class PartnerNavBar extends StatelessWidget {
  const PartnerNavBar({super.key, required this.current, this.onSelect});

  final PartnerTab current;
  final void Function(PartnerTab tab)? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.card,
        border: Border(top: BorderSide(color: RescueColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final tab in PartnerTab.values)
                _NavItem(
                  tab: tab,
                  active: tab == current,
                  onTap: () => onSelect?.call(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, this.onTap});

  final PartnerTab tab;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? RescueColors.primary : RescueColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? tab.activeIcon : tab.icon, size: 21, color: color),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: rescueFont(
                  11,
                  active ? 700 : 500,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
