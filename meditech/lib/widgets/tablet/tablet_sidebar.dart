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
        color: Color(0xFFF4F6F3),
        border: Border(
          right: BorderSide(color: Color(0xFFC5D5C9), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo and Brand header (no divider underneath)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/Meditech Logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
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
                          color: Color(0xFF306C42),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (appSubtitle != null)
                        Text(
                          appSubtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

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
                          color: const Color(0xFFE6F0E9),
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

          // Bottom Utility Links (Settings and Log out) – no divider above
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSettings)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSettingsTap,
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: const Color(0x0A111827),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: SizedBox(
                        height: _itemHeight,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, size: 20, color: Color(0xFF4B5563)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Branch settings',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLogoutTap,
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: const Color(0x0A111827),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: SizedBox(
                      height: _itemHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 20, color: Color(0xFFD32F2F)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                logoutLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(TabletNavigationItem item, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemSelected(item.id),
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0x0A111827),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: _itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFF306C42)
                      : const Color(0xFF4B5563),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF306C42)
                          : const Color(0xFF374151),
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
