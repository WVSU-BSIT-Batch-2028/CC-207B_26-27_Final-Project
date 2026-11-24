import 'package:flutter/material.dart';

import 'tablet_navigation_item.dart';

// Collapsible or fixed sidebar for tablet screens with role-based filtering
class TabletSidebar extends StatelessWidget {
  final String appTitle;
  final String? appSubtitle;
  final String userRole;
  final List<TabletNavigationItem> items;
  final String selectedItemId;
  final ValueChanged<String> onItemSelected;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;
  final bool showSettings;
  final String logoutLabel;

  const TabletSidebar({
    super.key,
    this.appTitle = 'MediTech',
    this.appSubtitle,
    required this.userRole,
    required this.items,
    required this.selectedItemId,
    required this.onItemSelected,
    this.onSettingsTap,
    this.onLogoutTap,
    this.showSettings = true,
    this.logoutLabel = 'Switch user / Log out',
  });

  static const double _itemHeight = 44.0;
  static const double _itemGap = 4.0;

  @override
  Widget build(BuildContext context) {
    // Only show items matching the current user's role
    final visibleItems = items.where((item) => item.isVisibleForRole(userRole)).toList();
    final selectedIndex = visibleItems.indexWhere((item) => item.id == selectedItemId);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        // Deep green sidebar — matches the approved prototype color scheme
        color: Color(0xFF1A5C35),
        border: Border(
          right: BorderSide(color: Color(0xFF155129), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo and Brand header — white on green
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF154D2D),
              border: Border(
                bottom: BorderSide(color: Color(0xFF155129), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_pharmacy,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        appTitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (appSubtitle != null)
                        Text(
                          appSubtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Navigation Links
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Stack(
                children: [
                  if (selectedIndex >= 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      top: selectedIndex * (_itemHeight + _itemGap),
                      left: 0,
                      right: 0,
                      height: _itemHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  Column(
                    children: [
                      for (int index = 0; index < visibleItems.length; index++) ...[
                        if (index > 0) const SizedBox(height: _itemGap),
                        _buildNavTile(
                          visibleItems[index],
                          visibleItems[index].id == selectedItemId,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),

          // Bottom Utility Links
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSettings)
                  _buildUtilityTile(
                    icon: Icons.settings_outlined,
                    label: 'Branch settings',
                    onTap: onSettingsTap,
                    danger: false,
                  ),
                _buildUtilityTile(
                  icon: Icons.logout,
                  label: logoutLabel,
                  onTap: onLogoutTap,
                  danger: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool danger,
  }) {
    final color = danger
        ? const Color(0xFFFFB3B3)
        : Colors.white.withValues(alpha: 0.65);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(TabletNavigationItem item, bool isSelected) {
    final iconColor = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.65);
    final textColor = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemSelected(item.id),
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withValues(alpha: 0.08),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: _itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Active indicator bar on left edge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: isSelected ? 20 : 0,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(item.icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
                if (item.badgeCount != null && item.badgeCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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