import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import '../services/cart_service.dart';

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