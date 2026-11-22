import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/shared/guest_auth_gate.dart';
import '../services/cart_service.dart';
import '../widgets/common/basket_bar.dart';
import 'cart_providers.dart';
import 'session_providers.dart';

const _addedToCartSnackDuration = Duration(seconds: 2);

// Adds a medicine to the customer's single-branch cart, asking confirmation
// if they already have items from a different pharmacy branch.
Future<void> addMedicineToCartWithBranchCheck({
  required BuildContext context,
  required WidgetRef ref,
  required String branchId,
  required String medicineId,
  required String medicineName,
  required String pharmacyName,
  bool showViewCartAction = false,
  Duration snackBarDuration = _addedToCartSnackDuration,
}) async {
  if (ref.read(sessionProvider) == null) {
    final signedIn = await showGuestAuthGate(
      context,
      title: 'Sign in to reserve',
      message:
          'Create or sign in to a MediTech account to add medicines and place a reservation.',
    );
    if (!context.mounted || !signedIn) return;
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
    showCustomerSnackBar(
      context,
      message: 'Added $medicineName to your cart.',
      duration: snackBarDuration,
      showBasket: true,
      action: showViewCartAction
          ? SnackBarAction(
              label: 'View Cart',
              onPressed: () {
                if (GoRouter.maybeOf(context) != null) {
                  context.push('/cart');
                }
              },
            )
          : null,
    );
  } on PostgrestException catch (error) {
    if (!context.mounted) return;
    showCustomerSnackBar(
      context,
      message: error.message.isNotEmpty
          ? error.message
          : 'Could not add this medicine to your cart.',
      duration: _addedToCartSnackDuration,
    );
  } catch (_) {
    if (!context.mounted) return;
    showCustomerSnackBar(
      context,
      message: 'Could not add this medicine to your cart. Try again.',
      duration: _addedToCartSnackDuration,
    );
  }
}