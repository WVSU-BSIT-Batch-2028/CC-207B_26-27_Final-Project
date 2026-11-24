import 'package:flutter/material.dart';

import 'tablet_frame.dart';
import 'tablet_navigation_item.dart';

// Pre-configured tablet shell for the MediTech Pharmacy app
class PharmacyFrame extends StatelessWidget {
  final String branchName;
  final String? branchMeta;
  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final int unreadNotifications;
  final int pendingReservationsCount;
  final int stockAlertsCount;
  final String selectedNavigationId;
  final ValueChanged<String> onNavigationSelected;
  final Widget body;
  final Widget? rightDrawer;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;

  const PharmacyFrame({
    super.key,
    required this.branchName,
    this.branchMeta,
    required this.userName,
    required this.userRole,
    this.userPhotoUrl,
    this.unreadNotifications = 0,
    this.pendingReservationsCount = 0,
    this.stockAlertsCount = 0,
    required this.selectedNavigationId,
    required this.onNavigationSelected,
    required this.body,
    this.rightDrawer,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onSettingsTap,
    this.onLogoutTap,
  });

  // Pharmacy navigation links with role filtering (Employees is owner-only)
  List<TabletNavigationItem> _buildNavigationItems() {
    return [
      const TabletNavigationItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        allowedRoles: ['owner', 'pharmacist', 'staff'],
      ),
      TabletNavigationItem(
        id: 'reservations',
        label: 'Reservations',
        icon: Icons.receipt_long_outlined,
        badgeCount: pendingReservationsCount,
        allowedRoles: ['owner', 'pharmacist', 'staff'],
      ),
      const TabletNavigationItem(
        id: 'inventory',
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        allowedRoles: ['owner', 'pharmacist', 'staff'],
      ),
      TabletNavigationItem(
        id: 'stock_alerts',
        label: 'Stock Alerts',
        icon: Icons.warning_amber_outlined,
        badgeCount: stockAlertsCount,
        allowedRoles: ['owner', 'pharmacist', 'staff'],
      ),
      const TabletNavigationItem(
        id: 'employees',
        label: 'Employees',
        icon: Icons.badge_outlined,
        allowedRoles: ['owner'],
      ),
      const TabletNavigationItem(
        id: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_none_outlined,
        allowedRoles: ['owner', 'pharmacist', 'staff'],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TabletFrame(
      appTitle: 'MediTech',
      branchTitle: branchName,
      branchSubtitle: branchMeta,
      userName: userName,
      userRole: userRole,
      userPhotoUrl: userPhotoUrl,
      unreadNotifications: unreadNotifications,
      navigationItems: _buildNavigationItems(),
      selectedNavigationId: selectedNavigationId,
      onNavigationSelected: onNavigationSelected,
      body: body,
      rightDrawer: rightDrawer,
      onNotificationsTap: onNotificationsTap,
      onProfileTap: onProfileTap,
      onSettingsTap: onSettingsTap,
      onLogoutTap: onLogoutTap,
      showSettings: true,
      logoutLabel: 'Switch user / Log out',
    );
  }
}