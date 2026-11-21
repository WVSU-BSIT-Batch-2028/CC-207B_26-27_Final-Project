import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_providers.dart';
import '../../widgets/tablet/admin_frame.dart';
import 'audit/audit_list_screen.dart';
import 'catalogue/catalogue_screen.dart';
import 'pharmacies/pharmacies_screen.dart';
import 'requests/medicine_requests_screen.dart';

// Approved admins land in the tablet shell instead of the sign-in page
class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({
    super.key,
    required this.section,
  });

  final String section;

  void _go(BuildContext context, String id) {
    switch (id) {
      case 'overview':
      case 'pharmacies':
        context.go('/pharmacies');
      case 'catalogue':
        context.go('/catalogue');
      case 'requests':
        context.go('/requests');
      case 'audit':
        context.go('/audit');
      default:
        context.go('/pharmacies');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = switch (section) {
      'catalogue' || 'requests' || 'audit' => section,
      _ => 'pharmacies',
    };

    final body = switch (selected) {
      'catalogue' => const CatalogueScreen(),
      'requests' => const MedicineRequestsScreen(),
      'audit' => const AuditListScreen(),
      _ => const PharmaciesScreen(),
    };

    return AdminFrame(
      adminName: 'Administrator',
      selectedNavigationId: selected == 'requests' ? 'catalogue' : selected,
      onNavigationSelected: (id) => _go(context, id),
      onLogoutTap: () async {
        await ref.read(sessionProvider.notifier).signOut();
        if (context.mounted) context.go('/');
      },
      body: body,
    );
  }
}
