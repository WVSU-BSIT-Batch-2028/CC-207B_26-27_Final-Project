import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_providers.dart';
import '../../providers/customer_nav_provider.dart';
import '../../providers/session_providers.dart';
import '../../screens/shared/guest_auth_gate.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Extra bottom inset for scroll views when the scaffold uses extendBody with [CustomerBottomChrome].
double customerBottomChromeScrollPadding(
  BuildContext context, {
  bool showBasket = false,
}) {
  final safe = MediaQuery.paddingOf(context).bottom;
  var height = safe + AppSpacing.md + 46 + AppSpacing.sm + 64 + AppSpacing.lg;
  if (showBasket) {
    height += 64 + AppSpacing.sm;
  }
  return height;
}

// Height from the physical bottom edge up to just above basket + nav (not list scroll padding).
double customerSnackBarBottomMargin(
  BuildContext context, {
  bool showBasket = false,
}) {
  final safe = MediaQuery.paddingOf(context).bottom;
  var height = safe + AppSpacing.sm + 64 + AppSpacing.sm;
  if (showBasket) {
    height += 64 + AppSpacing.sm;
  }
  return height;
}

OverlayEntry? _activeCustomerSnackEntry;

// Toast above bottom chrome; avoids scaffold resize and awkward mid-screen placement.
void showCustomerSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
  bool showBasket = true,
  SnackBarAction? action,
}) {
  _activeCustomerSnackEntry?.remove();
  _activeCustomerSnackEntry = null;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            customerSnackBarBottomMargin(context, showBasket: showBasket),
          ),
          action: action,
        ),
      );
    return;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final bottom = customerSnackBarBottomMargin(ctx, showBasket: showBasket);
      return Positioned(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: bottom,
        child: Material(
          elevation: 6,
          color: const Color(0xFF323232),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                if (action != null)
                  TextButton(
                    onPressed: action.onPressed,
                    child: Text(
                      action.label,
                      style: const TextStyle(color: AppColors.primaryLight),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  _activeCustomerSnackEntry = entry;
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (identical(_activeCustomerSnackEntry, entry)) {
      entry.remove();
      _activeCustomerSnackEntry = null;
    }
  });
}

// Basket pill, bottom nav, and the assistant button from the customer mock
class CustomerBottomChrome extends ConsumerWidget {
  const CustomerBottomChrome({
    super.key,
    this.showBasket = false,
    this.onViewCart,
  });

  final bool showBasket;
  final VoidCallback? onViewCart;

  Future<void> _selectTab(BuildContext context, WidgetRef ref, int index) async {
    if (index == 2 && ref.read(sessionProvider) == null) {
      await showGuestAuthGate(
        context,
        title: 'Sign in to track reservations',
        message:
            'See active pickups, confirmations, and past orders in one place.',
      );
      if (!context.mounted || ref.read(sessionProvider) == null) return;
    }
    if (index == 3 && ref.read(sessionProvider) == null) {
      await showGuestAuthGate(
        context,
        title: 'Sign in to open your profile',
        message: 'Manage your account, privacy notice, and password from here.',
      );
      if (!context.mounted || ref.read(sessionProvider) == null) return;
    }
    if (!context.mounted) return;
    ref.read(customerTabProvider.notifier).select(index);
    final router = GoRouter.maybeOf(context);
    if (router != null && router.state.matchedLocation != '/home') {
      context.go('/home');
    }
  }

  void _openAssistant(BuildContext context) {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/assistant');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(customerTabProvider);
    return Material(
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AiButton(onPressed: () => _openAssistant(context)),
            ),
          ),
          if (showBasket) ...[
            _BasketPill(onView: onViewCart),
            const SizedBox(height: AppSpacing.sm),
          ],
          _NavPill(
            currentIndex: currentIndex,
            onSelected: (index) => _selectTab(context, ref, index),
          ),
        ],
        ),
      ),
    );
  }
}

class _BasketPill extends ConsumerWidget {
  const _BasketPill({this.onView});

  final VoidCallback? onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider) != null;
    final count = signedIn ? ref.watch(cartItemCountProvider) : 0;
    final total = signedIn
        ? (ref.watch(cartProvider).value?.formattedSubtotal ?? '₱0.00')
        : '₱0.00';
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 40,
            child: Center(
              child: Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Basket ($count)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Est. total $total',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onView,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(72, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            tooltip: 'Home',
            selected: currentIndex == 0,
            onTap: () => onSelected(0),
          ),
          _NavItem(
            icon: Icons.search,
            selectedIcon: Icons.search,
            tooltip: 'Search',
            selected: currentIndex == 1,
            onTap: () => onSelected(1),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            tooltip: 'Reservations',
            selected: currentIndex == 2,
            onTap: () => onSelected(2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            tooltip: 'Profile',
            selected: currentIndex == 3,
            onTap: () => onSelected(3),
          ),
        ],
      ),
    );
  }
}

class _AiButton extends StatelessWidget {
  const _AiButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'AI Assistant',
      child: Material(
        color: AppColors.primary,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
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
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
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
      ),
    );
  }
}
