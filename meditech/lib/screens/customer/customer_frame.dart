import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/session_providers.dart';
import '../../screens/shared/sign_in_sheet.dart';
import '../../widgets/theme/app_colors.dart';
import 'cart/cart_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'reservations/my_reservations_screen.dart';
import 'reservations/reservation_details_screen.dart';
import 'search/search_screen.dart';

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

  // Guests sign in on this page, then return to the same screen
  Future<bool> _ensureSignedIn() async {
    if (ref.read(sessionProvider) != null) return true;
    await showCustomerSignInSheet(context);
    return mounted && ref.read(sessionProvider) != null;
  }

  Future<void> _openCart() async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (cartContext) => CartScreen(
          onBrowseMedicines: () {
            Navigator.of(cartContext).pop();
            _onTabSelected(1);
          },
          onOpenReservationDetails: (reservationId) {
            _onTabSelected(2);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReservationDetailsScreen(
                  reservationId: reservationId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    context.push('/notifications');
  }

  Future<void> _onDestinationSelected(int index) async {
    // Reservations and profile need a signed-in customer
    if ((index == 2 || index == 3) && ref.read(sessionProvider) == null) {
      if (!await _ensureSignedIn()) return;
    }
    if (!mounted) return;
    _onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onSearchTap: () => _onTabSelected(1),
        onViewAllPharmaciesTap: () => _onTabSelected(1),
      ),
      const SearchScreen(),
      MyReservationsScreen(
        onBrowseMedicines: () => _onTabSelected(1),
      ),
      const ProfileScreen(embedded: true),
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
            onPressed: () => context.push('/assistant'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: ref.watch(unreadNotificationCountProvider) > 0,
              label: Text('${ref.watch(unreadNotificationCountProvider)}'),
              child: const Icon(
                Icons.notifications_none,
                color: AppColors.text,
              ),
            ),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: 'Cart',
            icon: Badge(
              isLabelVisible: ref.watch(cartItemCountProvider) > 0,
              label: Text('${ref.watch(cartItemCountProvider)}'),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.text,
              ),
            ),
            onPressed: _openCart,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
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