import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/session_providers.dart';
import '../../screens/shared/guest_auth_gate.dart';
import '../../widgets/theme/app_colors.dart';
import '../../widgets/theme/app_spacing.dart';
import 'cart/cart_screen.dart';
import 'home/home_screen.dart';
import 'pharmacy/pharmacy_details_screen.dart';
import 'profile/profile_screen.dart';
import 'reservations/my_reservations_screen.dart';
import 'reservations/reservation_details_screen.dart';
import 'search/search_screen.dart';

// Main Flow customer shell: home browse, guest gates, AI FAB, bottom tabs
class CustomerFrame extends ConsumerStatefulWidget {
  const CustomerFrame({super.key, this.initialIndex = 0});

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

  Future<bool> _ensureSignedIn({
    required String title,
    required String message,
  }) async {
    if (ref.read(sessionProvider) != null) return true;
    await showGuestAuthGate(context, title: title, message: message);
    return mounted && ref.read(sessionProvider) != null;
  }

  Future<void> _openCart() async {
    if (!await _ensureSignedIn(
      title: 'Sign in to use your cart',
      message:
          'Save medicines from a pharmacy branch and submit a reservation when you are ready.',
    )) {
      return;
    }
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
    if (!await _ensureSignedIn(
      title: 'Sign in to get updates',
      message:
          'Notifications tell you when a pharmacy confirms your reservation or when it\'s ready for pickup.',
    )) {
      return;
    }
    if (!mounted) return;
    context.push('/notifications');
  }

  Future<void> _onDestinationSelected(int index) async {
    if (index == 2 && ref.read(sessionProvider) == null) {
      if (!await _ensureSignedIn(
        title: 'Sign in to track reservations',
        message:
            'See active pickups, confirmations, and past orders in one place.',
      )) {
        return;
      }
    }
    if (index == 3 && ref.read(sessionProvider) == null) {
      if (!await _ensureSignedIn(
        title: 'Sign in to open your profile',
        message: 'Manage your account, privacy notice, and password from here.',
      )) {
        return;
      }
    }
    if (!mounted) return;
    _onTabSelected(index);
  }

  Widget _circleAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onSearchTap: () => _onTabSelected(1),
        onViewAllPharmaciesTap: () => _onTabSelected(1),
        onOpenReservations: () => _onTabSelected(2),
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
        onOpenPharmacy: (pharmacy) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PharmacyDetailsScreen(
                branchId: pharmacy.branchId,
                initialTitle: pharmacy.pharmacyName,
              ),
            ),
          );
        },
      ),
      const SearchScreen(),
      MyReservationsScreen(
        onBrowseMedicines: () => _onTabSelected(1),
      ),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.lg,
        title: const SizedBox.shrink(),
        actions: [
          _circleAction(
            tooltip: 'Cart',
            icon: Icons.shopping_bag_outlined,
            badgeCount: ref.watch(cartItemCountProvider),
            onPressed: _openCart,
          ),
          _circleAction(
            tooltip: 'Notifications',
            icon: Icons.notifications_none,
            badgeCount: ref.watch(unreadNotificationCountProvider),
            onPressed: _openNotifications,
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      floatingActionButton: FloatingActionButton(
        tooltip: 'AI Assistant',
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/assistant'),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: AppColors.primary,
        indicatorColor: Colors.white.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.home, color: Colors.white),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search, color: Colors.white70),
            selectedIcon: Icon(Icons.search, color: Colors.white),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.receipt_long, color: Colors.white),
            label: 'My Reservations',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.white70),
            selectedIcon: Icon(Icons.person, color: Colors.white),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
