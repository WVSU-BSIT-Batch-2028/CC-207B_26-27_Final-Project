import 'package:flutter/material.dart';

// Represents one item in the tablet side navigation
class TabletNavigationItem {
  final String id;
  final String label;
  final IconData icon;
  final int? badgeCount;
  final List<String> allowedRoles;

  const TabletNavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badgeCount,
    this.allowedRoles = const ['owner', 'pharmacist', 'staff', 'admin'],
  });

  // Check if this item is accessible for a given user role
  bool isVisibleForRole(String role) {
    if (allowedRoles.isEmpty) return true;
    final normalized = role.trim().toLowerCase();
    if (normalized == 'administrator') {
      return allowedRoles.contains('admin') ||
          allowedRoles.contains('administrator');
    }
    return allowedRoles.contains(normalized);
  }
}