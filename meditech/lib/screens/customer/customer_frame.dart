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
import 'pharmacy/pharmacy_map_screen.dart';
import 'profile/profile_screen.dart';
import 'reservations/my_reservations_screen.dart';
import 'reservations/reservation_details_screen.dart';
import 'search/search_screen.dart';

// Main Flow customer shell matched to the Figma prototype
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        cartCount: ref.watch(cartItemCountProvider),
        notificationCount: ref.watch(unreadNotificationCountProvider),
        onCartTap: _openCart,
        onNotificationsTap: _openNotifications,
        onSearchTap: () => _onTabSelected(1),
        onViewAllPharmaciesTap: () => _onTabSelected(1),
        onViewMapsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PharmacyMapScreen(),
            ),
          );
        },
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
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: screens),
      ),
      // Only on Home so the FAB does not block Search medicine taps
      floatingActionButton: _currentIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton(
                tooltip: 'AI Assistant',
                backgroundColor: AppColors.primary,
                elevation: 2,
                onPressed: () => context.push('/assistant'),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                selected: _currentIndex == 0,
                onTap: () => _onDestinationSelected(0),
              ),
              _NavItem(
                icon: Icons.search,
                selectedIcon: Icons.search,
                selected: _currentIndex == 1,
                onTap: () => _onDestinationSelected(1),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                selected: _currentIndex == 2,
                onTap: () => _onDestinationSelected(2),
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                selected: _currentIndex == 3,
                onTap: () => _onDestinationSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          selected ? selectedIcon : icon,
          color: selected ? AppColors.primary : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
