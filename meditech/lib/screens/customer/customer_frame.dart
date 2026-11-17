import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/theme/app_colors.dart';
import 'home/home_screen.dart';

// Main navigation frame for the customer app with header badges and bottom tabs
class CustomerFrame extends ConsumerStatefulWidget {
  const CustomerFrame({super.key, this.initialIndex = 0});

  // Starting active tab index
  final int initialIndex;

  @override
  ConsumerState<CustomerFrame> createState() => _CustomerFrameState();
}

class _CustomerFrameState extends ConsumerState<CustomerFrame> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onSearchTap: () => _onTabSelected(1),
        onViewAllPharmaciesTap: () => _onTabSelected(1),
      ),
      const _CustomerTabPlaceholder(
        title: 'Search Medicines',
        description: 'Find medicines, compare prices, and locate pharmacies nearby.',
        icon: Icons.search,
      ),
      const _CustomerTabPlaceholder(
        title: 'My Reservations',
        description: 'View active orders, pickup codes, and history.',
        icon: Icons.receipt_long_outlined,
      ),
      const _CustomerTabPlaceholder(
        title: 'Profile',
        description: 'Manage personal details, saved prescriptions, and security.',
        icon: Icons.person_outline,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MediTech',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'AI Assistant',
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('MediTech AI Assistant coming soon.')),
              );
            },
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Badge(
              child: Icon(Icons.notifications_none, color: AppColors.text),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon.')),
              );
            },
          ),
          IconButton(
            tooltip: 'Cart',
            icon: const Badge(
              child: Icon(Icons.shopping_bag_outlined, color: AppColors.text),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart is empty.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: AppColors.primary),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
            label: 'My Reservations',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Temporary view shown while other tabs are being implemented
class _CustomerTabPlaceholder extends StatelessWidget {
  const _CustomerTabPlaceholder({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}