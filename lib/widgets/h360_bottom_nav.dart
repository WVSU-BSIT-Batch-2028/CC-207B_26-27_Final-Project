import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// One tab in the bottom navigation.
class NavDestination {
  const NavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Custom bottom navigation with an animated "pill" behind the active icon.
/// Tabs come from the prototype: pass [patientItems] or [doctorItems].
class H360BottomNav extends StatelessWidget {
  const H360BottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavDestination> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Patient: Home / Appointment / Prescription / Records / Profile
  static const List<NavDestination> patientItems = [
    NavDestination(Icons.home_rounded, 'Home'),
    NavDestination(Icons.event_note_rounded, 'Appointment'),
    NavDestination(Icons.medication_rounded, 'Prescription'),
    NavDestination(Icons.folder_shared_rounded, 'Records'),
    NavDestination(Icons.person_rounded, 'Profile'),
  ];

  /// Doctor: Home / Appointments / Patients / Profile / Menu (opens the drawer)
  static const List<NavDestination> doctorItems = [
    NavDestination(Icons.home_rounded, 'Home'),
    NavDestination(Icons.event_note_rounded, 'Appointments'),
    NavDestination(Icons.groups_rounded, 'Patients'),
    NavDestination(Icons.person_rounded, 'Profile'),
    NavDestination(Icons.menu_rounded, 'Menu'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(color: Color(0x181D4ED8), blurRadius: 22, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final NavDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: selected ? 58 : 40,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, size: 24, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
