import 'package:flutter/material.dart';

import '../../features/rescue/presentation/widgets/rescue_widgets.dart';

/// The five consumer tabs. Ordered as they appear in the designs.
enum ConsumerTab {
  home('Home', Icons.home_rounded, Icons.home_outlined),
  explore('Explore', Icons.explore_rounded, Icons.explore_outlined),
  activity('Activity', Icons.monitor_heart_rounded, Icons.monitor_heart_outlined),
  impact('Impact', Icons.eco_rounded, Icons.eco_outlined),
  profile('Profile', Icons.person_rounded, Icons.person_outline_rounded);

  const ConsumerTab(this.label, this.activeIcon, this.icon);

  final String label;
  final IconData activeIcon;
  final IconData icon;
}

/// Fixed bottom navigation shared by every consumer tab screen.
///
/// Only [ConsumerTab.home] has a destination so far; the other four call
/// [onSelect] and the router decides. They stay inert until their screens are
/// built.
class ConsumerNavBar extends StatelessWidget {
  const ConsumerNavBar({super.key, required this.current, this.onSelect});

  final ConsumerTab current;
  final void Function(ConsumerTab tab)? onSelect;

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
              for (final tab in ConsumerTab.values)
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

  final ConsumerTab tab;
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
