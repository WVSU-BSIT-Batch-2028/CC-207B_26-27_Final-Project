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
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo and Brand header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6B3E),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E6B3E),
                          letterSpacing: -0.3,
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

          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),

          // Navigation Links with a single smoothly sliding active highlight pill
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                children: [
                  if (selectedIndex >= 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      top: selectedIndex * (_itemHeight + _itemGap),
                      left: 0,
                      right: 0,
                      height: _itemHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
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

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Bottom Utility Links (Settings and Log out)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSettings)
                  InkWell(
                    onTap: onSettingsTap,
                    borderRadius: BorderRadius.circular(8),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 20, color: Color(0xFF6B7280)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Branch settings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                InkWell(
                  onTap: onLogoutTap,
                  borderRadius: BorderRadius.circular(8),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 20, color: Color(0xFFD32F2F)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            logoutLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                        ),
                      ],
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
        hoverColor: isSelected ? Colors.transparent : const Color(0x0A111827),
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
                      ? const Color(0xFF1E6B3E)
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
                          ? const Color(0xFF1E6B3E)
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