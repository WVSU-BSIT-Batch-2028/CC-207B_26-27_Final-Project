import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_providers.dart';
import '../../providers/customer_nav_provider.dart';
import '../../providers/notification_providers.dart';
import '../../providers/session_providers.dart';
import '../../screens/shared/guest_auth_gate.dart';
import '../../widgets/common/basket_bar.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'reservations/my_reservations_screen.dart';
import 'search/search_screen.dart';

// Main Flow customer shell matched to the Figma prototype
class CustomerFrame extends ConsumerStatefulWidget {
  const CustomerFrame({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<CustomerFrame> createState() => _CustomerFrameState();
}

class _CustomerFrameState extends ConsumerState<CustomerFrame> {
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(customerTabProvider.notifier).select(widget.initialIndex);
        }
      });
    }
  }

  void _onTabSelected(int index) {
    ref.read(customerTabProvider.notifier).select(index);
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
    context.push('/cart');
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

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(customerTabProvider);
    final signedIn = ref.watch(sessionProvider) != null;
    final screens = [
      HomeScreen(
        cartCount: signedIn ? ref.watch(cartItemCountProvider) : 0,
        notificationCount:
            signedIn ? ref.watch(unreadNotificationCountProvider) : 0,
        onCartTap: _openCart,
        onNotificationsTap: _openNotifications,
        onSearchTap: () => _onTabSelected(1),
        onViewMapsTap: () => context.push('/map'),
        onOpenReservations: () => _onTabSelected(2),
        onOpenReservationDetails: (reservationId) {
          _onTabSelected(2);
          context.push('/reservations/$reservationId');
        },
        onOpenPharmacy: (pharmacy) {
          final name = Uri.encodeComponent(pharmacy.pharmacyName);
          context.push('/pharmacies/${pharmacy.branchId}?name=$name');
        },
      ),
      SearchScreen(onBack: () => _onTabSelected(0)),
      MyReservationsScreen(
        onBrowseMedicines: () => _onTabSelected(1),
      ),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: currentIndex, children: screens),
      ),
      bottomNavigationBar: CustomerBottomChrome(
        showBasket: signedIn && currentIndex == 1,
        onViewCart: _openCart,
      ),
    );
  }
}
