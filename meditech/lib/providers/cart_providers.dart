import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart.dart';
import '../screens/customer/cart/cart_screen.dart';
import '../screens/shared/guest_auth_gate.dart';
import '../services/cart_service.dart';
import 'session_providers.dart';

// Provides CartService (overridable in widget tests)
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService();
});

// Manages the signed-in customer's cart state across screens
class CartNotifier extends AsyncNotifier<CustomerCart> {
  @override
  Future<CustomerCart> build() async {
    final service = ref.watch(cartServiceProvider);
    return service.getMyCart();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cartServiceProvider).getMyCart(),
    );
  }

  // Attempts to add an item; returns AddToCartOutcome.branchConflict if the
  // cart already belongs to a different pharmacy branch.
  Future<AddToCartOutcome> addItem({
    required String branchId,
    required String medicineId,
    int quantity = 1,
    bool replaceBranch = false,
  }) async {
    final service = ref.read(cartServiceProvider);
    final outcome = await service.addToCart(
      branchId: branchId,
      medicineId: medicineId,
      quantity: quantity,
      replaceBranch: replaceBranch,
    );

    if (outcome == AddToCartOutcome.added) {
      await refresh();
    }
    return outcome;
  }

  Future<void> setQuantity({
    required String medicineId,
    required int quantity,
  }) async {
    final service = ref.read(cartServiceProvider);
    await service.setItemQuantity(
      medicineId: medicineId,
      quantity: quantity,
    );
    await refresh();
  }

  Future<void> clearCart() async {
    final service = ref.read(cartServiceProvider);
    await service.clearCart();
    await refresh();
  }

  Future<void> uploadPrescription({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final service = ref.read(cartServiceProvider);
    await service.uploadPrescription(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    await refresh();
  }

  Future<void> removePrescription(CartPrescriptionFile file) async {
    final service = ref.read(cartServiceProvider);
    await service.removePrescription(file);
    await refresh();
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, CustomerCart>(
  CartNotifier.new,
);

// Convenience badge count of total medicine units in cart
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).value?.totalUnits ?? 0;
});

// Adds a medicine to the customer's single-branch cart, asking confirmation
// if they already have items from a different pharmacy branch.
Future<void> addMedicineToCartWithBranchCheck({
  required BuildContext context,
  required WidgetRef ref,
  required String branchId,
  required String medicineId,
  required String medicineName,
  required String pharmacyName,
}) async {
  // Guests must sign in before reserving (DB requires a customer account)
  if (ref.read(sessionProvider) == null) {
    final signedIn = await showGuestAuthGate(
      context,
      title: 'Sign in to reserve',
      message:
          'Create or sign in to a MediTech account to add medicines and place a reservation.',
    );
    if (!context.mounted || !signedIn) return;
    // Reload cart against the new customer session before adding
    await ref.read(cartProvider.notifier).refresh();
  }

  final notifier = ref.read(cartProvider.notifier);

  try {
    final outcome = await notifier.addItem(
      branchId: branchId,
      medicineId: medicineId,
    );

    if (!context.mounted) return;

    if (outcome == AddToCartOutcome.branchConflict) {
      final currentPharmacy =
          ref.read(cartProvider).value?.pharmacyName ?? 'another pharmacy';
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
            'Your cart already contains items from $currentPharmacy. '
            'Replace your current cart with items from $pharmacyName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Current'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace Cart'),
            ),
          ],
        ),
      );

      if (replace != true) return;

      await notifier.addItem(
        branchId: branchId,
        medicineId: medicineId,
        replaceBranch: true,
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $medicineName from $pharmacyName.'),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
  } on PostgrestException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.message.isNotEmpty
              ? error.message
              : 'Could not add this medicine to your cart.',
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not add this medicine to your cart. Try again.'),
      ),
    );
  }
}
