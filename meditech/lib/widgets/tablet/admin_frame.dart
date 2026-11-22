import 'package:flutter/material.dart';

import 'tablet_frame.dart';
import 'tablet_navigation_item.dart';

// Pre-configured tablet shell for the MediTech Administrator portal
class AdminFrame extends StatelessWidget {
  final String headerTitle;
  final String? headerSubtitle;
  final String adminName;
  final int unreadNotifications;
  final int pendingPharmaciesCount;
  final int medicineRequestsCount;
  final String selectedNavigationId;
  final ValueChanged<String> onNavigationSelected;
  final Widget body;
  final Widget? rightDrawer;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  const AdminFrame({
    super.key,
    this.headerTitle = 'MediTech Administration',
    this.headerSubtitle,
    required this.adminName,
    this.unreadNotifications = 0,
    this.pendingPharmaciesCount = 0,
    this.medicineRequestsCount = 0,
    required this.selectedNavigationId,
    required this.onNavigationSelected,
    required this.body,
    this.rightDrawer,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  // Administrator sidebar navigation items
  List<TabletNavigationItem> _buildNavigationItems() {
    return [
      const TabletNavigationItem(
        id: 'overview',
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        allowedRoles: ['admin'],
      ),
      const TabletNavigationItem(
        id: 'listings',
        label: 'Not on MediTech',
        icon: Icons.location_off_outlined,
        allowedRoles: ['admin'],
      ),
      TabletNavigationItem(
        id: 'pharmacies',
        label: 'Pharmacies',
        icon: Icons.store_mall_directory_outlined,
        badgeCount: pendingPharmaciesCount,
        allowedRoles: ['admin'],
      ),
      TabletNavigationItem(
        id: 'catalogue',
        label: 'Medicine Catalogue',
        icon: Icons.medication_outlined,
        badgeCount: medicineRequestsCount,
        allowedRoles: ['admin'],
      ),
      const TabletNavigationItem(
        id: 'audit',
        label: 'Audit Records',
        icon: Icons.fact_check_outlined,
        allowedRoles: ['admin'],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return TabletFrame(
      appTitle: 'MediTech',
      appSubtitle: 'Admin',
      branchTitle: headerTitle,
      branchSubtitle: headerSubtitle,
      userName: adminName,
      userRole: 'Administrator',
      unreadNotifications: unreadNotifications,
      navigationItems: _buildNavigationItems(),
      selectedNavigationId: selectedNavigationId,
      onNavigationSelected: onNavigationSelected,
      body: body,
      rightDrawer: rightDrawer,
      onNotificationsTap: onNotificationsTap,
      onProfileTap: onProfileTap,
      onLogoutTap: onLogoutTap,
      showSettings: false,
      logoutLabel: 'Log out',
    );
  }
}