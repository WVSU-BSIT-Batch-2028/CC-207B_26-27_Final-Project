import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/notification_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/tablet/admin_frame.dart';
import 'audit/audit_list_screen.dart';
import 'catalogue/catalogue_screen.dart';
import 'listings/osm_listings_screen.dart';
import 'overview/admin_overview_screen.dart';
import 'pharmacies/pharmacies_screen.dart';
import 'requests/medicine_requests_screen.dart';

// Approved admins land in the tablet shell instead of the sign-in page
class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key, required this.section});

  final String section;

  void _go(BuildContext context, String id) {
    switch (id) {
      case 'overview':
        context.go('/overview');
      case 'pharmacies':
        context.go('/pharmacies');
      case 'listings':
        context.go('/listings');
      case 'catalogue':
        context.go('/catalogue');
      case 'requests':
        context.go('/requests');
      case 'audit':
        context.go('/audit');
      default:
        context.go('/overview');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final selected = switch (section) {
      'overview' ||
      'pharmacies' ||
      'listings' ||
      'catalogue' ||
      'requests' ||
      'audit' => section,
      _ => 'overview',
    };

    final body = switch (selected) {
      'pharmacies' => const PharmaciesScreen(),
      'listings' => const OsmListingsScreen(),
      'catalogue' => const CatalogueScreen(),
      'requests' => const MedicineRequestsScreen(),
      'audit' => const AuditListScreen(),
      _ => const AdminOverviewScreen(showHeader: false),
    };

    return AdminFrame(
      adminName: 'Administrator',
      unreadNotifications: unread,
      selectedNavigationId: selected == 'requests' ? 'catalogue' : selected,
      onNavigationSelected: (id) => _go(context, id),
      onNotificationsTap: () => context.push('/notifications'),
      onLogoutTap: () async {
        await ref.read(sessionProvider.notifier).signOut();
        if (context.mounted) context.go('/');
      },
      body: body,
    );
  }
}
