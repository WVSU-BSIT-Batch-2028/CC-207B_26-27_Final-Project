import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/cart.dart';
import '../../../providers/cart_providers.dart';
import '../../../providers/reservation_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../reservations/reservation_submitted_screen.dart';

// Customer cart screen matching wireframes P-15, P-17, and P-18
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({
    super.key,
    this.isOffline = false,
    this.onBrowseMedicines,
    this.onPickPrescription,
    this.onReservationSubmitted,
    this.onOpenReservationDetails,
  });

  final bool isOffline;
  final VoidCallback? onBrowseMedicines;
  final Future<void> Function(WidgetRef ref)? onPickPrescription;
  final void Function(String reservationId, String referenceNo)?
  onReservationSubmitted;
  final void Function(String reservationId)? onOpenReservationDetails;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _busy = false;
  bool _acknowledged = false;
  String? _idempotencyKey;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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

  // Calls submit_reservation and navigates to the confirmation screen (P-19)
  Future<void> _placeReservation(CustomerCart cart) async {
    if (!_acknowledged || !cart.canSubmitReservation) return;

    // Reuse the same idempotency key if a retry happens on network failure
    _idempotencyKey ??= ref
        .read(reservationServiceProvider)
        .generateIdempotencyKey();

    final snapshotItems = List<CartItem>.from(cart.items);
    final snapshotPharmacy = cart.pharmacyName ?? 'Pharmacy';
    final snapshotBranch = cart.branchName ?? '';
    final snapshotTotal = cart.subtotal;

    final result = await ref
        .read(myReservationsProvider.notifier)
        .submitReservation(
          idempotencyKey: _idempotencyKey!,
          acknowledged: _acknowledged,
        );

    _idempotencyKey = null;
    if (!mounted) return;

    if (widget.onReservationSubmitted != null) {
      widget.onReservationSubmitted!(result.reservationId, result.referenceNo);
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (submittedContext) => ReservationSubmittedScreen(
          reservationId: result.reservationId,
          referenceNo: result.referenceNo,
          pharmacyName: snapshotPharmacy,
          branchName: snapshotBranch,
          items: snapshotItems,
          totalAmount: snapshotTotal,
          onViewReservation: widget.onOpenReservationDetails == null
              ? null
              : () {
                  Navigator.of(submittedContext).pop();
                  widget.onOpenReservationDetails!(result.reservationId);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
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
                              onUpload: cart.prescriptions.length < 3
                                  ? () =>
                                        _runAction(_pickAndUploadPrescription)
                                  : null,
                              onRemoveFile: (file) => _runAction(
                                () => ref
                                    .read(cartProvider.notifier)
                                    .removePrescription(file),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          // Total, acknowledgment checkbox, and Place Reservation button
                          _CartCheckoutCard(
                            cart: cart,
                            busy: _busy,
                            acknowledged: _acknowledged,
                            onAcknowledgedChanged: (value) {
                              setState(() => _acknowledged = value ?? false);
                            },
                            onPlaceReservation:
                                (cart.canSubmitReservation && _acknowledged)
                                ? () => _runAction(() => _placeReservation(cart))
                                : null,
                          ),
                        ],
                      ),
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

  String? _mimeTypeForFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return null;
    final ext = fileName.substring(dotIndex + 1).toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }

  // Opens the device file picker for JPEG, PNG, or PDF prescriptions (max 5 MB)
  Future<void> _pickAndUploadPrescription() async {
    if (widget.onPickPrescription != null) {
      await widget.onPickPrescription!(ref);
      return;
    }

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (files.isEmpty) return;

    final picked = files.single;
    final mimeType = _mimeTypeForFileName(picked.name);
    if (mimeType == null) {
      throw StateError('Choose a JPEG, PNG, or PDF file.');
    }

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Could not read the selected file.');
    }
    if (bytes.lengthInBytes > 5242880) {
      throw StateError('File exceeds the 5 MB limit.');
    }

    await ref
        .read(cartProvider.notifier)
        .uploadPrescription(
          fileName: picked.name,
          bytes: bytes,
          mimeType: mimeType,
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
                  const Text(
                    'PICKUP AT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cart.pharmacyName ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if ((cart.branchName ?? '').isNotEmpty)
                    Text(
                      cart.branchName!,
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
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'One pharmacy per reservation and pickup code.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                        '${item.genericName} · ${item.strength} · ${item.dosageForm}',
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
                Expanded(
                  child: Text(
                    'Prescription needed (${prescriptions.length}/3)',
                    style: const TextStyle(
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
              'Upload your prescription for the Rx items. Non-Rx items don\'t need it. The pharmacist checks it before confirming.',
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
                    ? 'Take photo or choose file'
                    : 'Add another file',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'JPG, PNG, or PDF · up to 3 files · max 5 MB each. Bring the original at pickup.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartCheckoutCard extends StatelessWidget {
  const _CartCheckoutCard({
    required this.cart,
    required this.busy,
    required this.acknowledged,
    required this.onAcknowledgedChanged,
    this.onPlaceReservation,
  });

  final CustomerCart cart;
  final bool busy;
  final bool acknowledged;
  final ValueChanged<bool?> onAcknowledgedChanged;
  final VoidCallback? onPlaceReservation;

  @override
  Widget build(BuildContext context) {
    String? blockerMessage;
    if (cart.hasUnavailableItems) {
      blockerMessage = 'Remove unavailable items before placing a reservation.';
    } else if (cart.hasRxItems && cart.prescriptions.isEmpty) {
      blockerMessage = 'Upload at least one prescription file to continue.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total reported amount (${cart.totalUnits} ${cart.totalUnits == 1 ? 'unit' : 'units'})',
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
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Prices and availability are reported by the pharmacy and are confirmed only when the pharmacy confirms your reservation.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: acknowledged,
              onChanged: busy ? null : onAcknowledgedChanged,
              title: const Text(
                'I understand that this is a reservation request and is not confirmed until the pharmacy responds.',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
            if (blockerMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                blockerMessage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: busy ? null : onPlaceReservation,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Place reservation'),
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
              'Your cart is empty.',
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