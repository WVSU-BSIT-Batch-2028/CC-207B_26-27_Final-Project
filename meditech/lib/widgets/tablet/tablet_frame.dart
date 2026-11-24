import 'package:flutter/material.dart';

import 'tablet_header.dart';
import 'tablet_navigation_item.dart';
import 'tablet_sidebar.dart';

// Responsive master shell for tablet screens (Pharmacy and Admin apps)
class TabletFrame extends StatelessWidget {
  final String appTitle;
  final String? appSubtitle;
  final String branchTitle;
  final String? branchSubtitle;
  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final int unreadNotifications;
  final List<TabletNavigationItem> navigationItems;
  final String selectedNavigationId;
  final ValueChanged<String> onNavigationSelected;
  final Widget body;
  final Widget? rightDrawer;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;
  final bool showSettings;
  final String logoutLabel;

  const TabletFrame({
    super.key,
    this.appTitle = 'MediTech',
    this.appSubtitle,
    required this.branchTitle,
    this.branchSubtitle,
    required this.userName,
    required this.userRole,
    this.userPhotoUrl,
    this.unreadNotifications = 0,
    required this.navigationItems,
    required this.selectedNavigationId,
    required this.onNavigationSelected,
    required this.body,
    this.rightDrawer,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onSettingsTap,
    this.onLogoutTap,
    this.showSettings = true,
    this.logoutLabel = 'Switch user / Log out',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar (Navigation links filtered by role)
          TabletSidebar(
            appTitle: appTitle,
            appSubtitle: appSubtitle,
            userRole: userRole,
            items: navigationItems,
            selectedItemId: selectedNavigationId,
            onItemSelected: onNavigationSelected,
            onSettingsTap: onSettingsTap,
            onLogoutTap: onLogoutTap,
            showSettings: showSettings,
            logoutLabel: logoutLabel,
          ),

          // Main Center Area (Header + Body + Right Drawer)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Bar
                TabletHeader(
                  title: branchTitle,
                  subtitle: branchSubtitle,
                  userName: userName,
                  userRole: userRole,
                  userPhotoUrl: userPhotoUrl,
                  unreadNotifications: unreadNotifications,
                  onNotificationsTap: onNotificationsTap,
                  onProfileTap: onProfileTap,
                ),

                // Main Content Row (Page Body + Side-by-side or overlay Details Drawer)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Page Body
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: body,
                        ),
                      ),

                      // Optional Right Details Drawer (Side-by-side)
                      ?rightDrawer,
                    ],
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