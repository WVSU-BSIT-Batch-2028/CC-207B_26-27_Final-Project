import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/cart.dart';
import '../../../providers/cart_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Customer cart screen matching wireframes P-13 (empty) and P-14 (active cart)
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({
    super.key,
    this.isOffline = false,
    this.onBrowseMedicines,
    this.onPickPrescription,
    this.onProceedToReservation,
  });

  final bool isOffline;
  final VoidCallback? onBrowseMedicines;
  final Future<void> Function(WidgetRef ref)? onPickPrescription;
  final void Function(CustomerCart cart)? onProceedToReservation;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _busy = false;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text(
          'All medicines in your current cart will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runAction(() => ref.read(cartProvider.notifier).clearCart());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (cartAsync.value?.isNotEmpty == true)
            TextButton(
              onPressed: _busy ? null : _confirmClearCart,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isOffline) const OfflineBanner(),
          Expanded(
            child: AsyncView<CustomerCart>(
              value: cartAsync,
              onRetry: () => ref.read(cartProvider.notifier).refresh(),
              builder: (cart) {
                if (cart.isEmpty) {
                  return _EmptyCartView(
                    onBrowseMedicines: () {
                      if (widget.onBrowseMedicines != null) {
                        widget.onBrowseMedicines!();
                        return;
                      }
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          // Selected single-branch banner
                          _BranchBanner(cart: cart),
                          const SizedBox(height: AppSpacing.md),
                          // Line items
                          ...cart.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _CartItemCard(
                                item: item,
                                busy: _busy,
                                onDecrement: () => _runAction(
                                  () => ref
                                      .read(cartProvider.notifier)
                                      .setQuantity(
                                        medicineId: item.medicineId,
                                        quantity: item.quantity - 1,
                                      ),
                                ),
                                onIncrement: () => _runAction(
                                  () => ref
                                      .read(cartProvider.notifier)
                                      .setQuantity(
                                        medicineId: item.medicineId,
                                        quantity: item.quantity + 1,
                                      ),
                                ),
                                onRemove: () => _runAction(
                                  () => ref
                                      .read(cartProvider.notifier)
                                      .setQuantity(
                                        medicineId: item.medicineId,
                                        quantity: 0,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          // Rx prescription upload section (when any Rx item is in cart)
                          if (cart.hasRxItems) ...[
                            const SizedBox(height: AppSpacing.md),
                            _PrescriptionUploadCard(
                              prescriptions: cart.prescriptions,
                              busy: _busy,
                              onUpload: widget.onPickPrescription == null
                                  ? null
                                  : () => _runAction(
                                      () => widget.onPickPrescription!(ref),
                                    ),
                              onRemoveFile: (file) => _runAction(
                                () => ref
                                    .read(cartProvider.notifier)
                                    .removePrescription(file),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Sticky subtotal & reservation checkout bar
                    _CartCheckoutBar(
                      cart: cart,
                      busy: _busy,
                      onProceed: cart.canSubmitReservation
                          ? () {
                              if (widget.onProceedToReservation != null) {
                                widget.onProceedToReservation!(cart);
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cart verified — ready for reservation summary.',
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchBanner extends StatelessWidget {
  const _BranchBanner({required this.cart});

  final CustomerCart cart;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.local_pharmacy_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cart.pharmacyName ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    cart.branchName ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cart.branchAddress ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final CartItem item;
  final bool busy;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final availabilityCode = item.availability.name == 'lowStock'
        ? 'low_stock'
        : item.availability.name;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.brandName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.genericName} · ${item.strength}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isRx) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const StatusBadge.rx(),
                ],
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  item.formattedUnitPrice,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge.availability(availabilityCode),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity stepper
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease quantity',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: busy ? null : onDecrement,
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase quantity',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: busy ? null : onIncrement,
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.formattedLineTotal,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionUploadCard extends StatelessWidget {
  const _PrescriptionUploadCard({
    required this.prescriptions,
    required this.busy,
    required this.onRemoveFile,
    this.onUpload,
  });

  final List<CartPrescriptionFile> prescriptions;
  final bool busy;
  final VoidCallback? onUpload;
  final void Function(CartPrescriptionFile file) onRemoveFile;

  @override
  Widget build(BuildContext context) {
    final missingRx = prescriptions.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  missingRx
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: missingRx ? AppColors.warning : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Prescription required',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Attach a clear photo or PDF of your prescription (JPEG, PNG, or PDF, up to 5 MB).',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (prescriptions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...prescriptions.map(
                (file) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(file.formattedSize),
                  trailing: IconButton(
                    tooltip: 'Remove prescription',
                    onPressed: busy ? null : () => onRemoveFile(file),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: busy ? null : onUpload,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                prescriptions.isEmpty
                    ? 'Upload Prescription'
                    : 'Add Another Prescription',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartCheckoutBar extends StatelessWidget {
  const _CartCheckoutBar({
    required this.cart,
    required this.busy,
    this.onProceed,
  });

  final CustomerCart cart;
  final bool busy;
  final VoidCallback? onProceed;

  @override
  Widget build(BuildContext context) {
    String? blockerMessage;
    if (cart.hasUnavailableItems) {
      blockerMessage = 'Remove unavailable items before reserving.';
    } else if (cart.hasRxItems && cart.prescriptions.isEmpty) {
      blockerMessage = 'Upload your prescription above to continue.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (blockerMessage != null) ...[
              Text(
                blockerMessage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cart.totalUnits} ${cart.totalUnits == 1 ? 'item' : 'items'})',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  cart.formattedSubtotal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: busy ? null : onProceed,
              child: const Text('Proceed to Reservation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView({required this.onBrowseMedicines});

  final VoidCallback onBrowseMedicines;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Search for medicines and add items from one pharmacy branch to reserve.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onBrowseMedicines,
              child: const Text('Browse Medicines'),
            ),
          ],
        ),
      ),
    );
  }
}
