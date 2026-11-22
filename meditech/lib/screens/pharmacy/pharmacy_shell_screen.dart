import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_providers.dart';
import '../../widgets/tablet/pharmacy_frame.dart';
import 'branch_settings/branch_settings_screen.dart';
import 'dashboard/pharmacy_dashboard_screen.dart';
import 'inventory/inventory_screen.dart';
import 'reservations/reservations_screen.dart';
import 'stock_alerts/stock_alerts_screen.dart';

// Approved pharmacy staff land here instead of staying on sign-in
class PharmacyShellScreen extends ConsumerWidget {
  const PharmacyShellScreen({
    super.key,
    required this.section,
  });

  final String section;

  void _go(BuildContext context, String id) {
    switch (id) {
      case 'dashboard':
        context.go('/dashboard');
      case 'reservations':
        context.go('/reservations');
      case 'inventory':
        context.go('/inventory');
      case 'stock_alerts':
        context.go('/inventory'); // or stays in shell
      case 'employees':
        context.go('/employees');
      case 'notifications':
        context.push('/notifications');
      default:
        context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionProvider);
    final role = account?.role ?? 'staff';
    final selected = section;

    final body = switch (selected) {
      'reservations' => const ReservationsScreen(),
      'inventory' => const InventoryScreen(),
      'stock_alerts' => const StockAlertsScreen(),
      'settings' => const BranchSettingsScreen(),
      _ => PharmacyDashboardScreen(),
    };

    return PharmacyFrame(
      branchName: 'Pharmacy branch',
      userName: role == 'owner' ? 'Branch Owner' : 'Staff',
      userRole: role,
      selectedNavigationId: selected,
      onNavigationSelected: (id) => _go(context, id),
      onNotificationsTap: () => _go(context, 'notifications'),
      onSettingsTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BranchSettingsScreen()),
        );
      },
      onLogoutTap: () async {
        await ref.read(sessionProvider.notifier).signOut();
        if (context.mounted) context.go('/');
      },
      body: body,
    );
  }
}

