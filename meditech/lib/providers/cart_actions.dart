import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/cart_service.dart';
import 'cart_providers.dart';

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
  final notifier = ref.read(cartProvider.notifier);
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
          if (GoRouter.maybeOf(context) != null) {
            context.push('/cart');
          }
        },
      ),
    ),
  );
}
