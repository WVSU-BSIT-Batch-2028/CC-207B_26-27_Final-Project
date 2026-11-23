import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/cart.dart';
import '../../../providers/cart_providers.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../providers/customer_nav_provider.dart';
import '../../../providers/reservation_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/basket_bar.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../reservations/reservation_submitted_screen.dart';
import '../pharmacy/directions_screen.dart';
import '../pharmacy/pharmacy_details_screen.dart';

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
  String? _updatingMedicineId;
  bool _acknowledged = false;
  String? _idempotencyKey;

  Future<void> _setItemQuantity(String medicineId, int quantity) async {
    setState(() => _updatingMedicineId = medicineId);
    try {
      await ref
          .read(cartProvider.notifier)
          .setQuantity(medicineId: medicineId, quantity: quantity);
    } catch (error) {
      if (!mounted) return;
      showCustomerSnackBar(
        context,
        message: 'Could not update quantity. Try again.',
        showBasket: false,
      );
    } finally {
      if (mounted) setState(() => _updatingMedicineId = null);
    }
  }

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
    final snapshotBranchId = cart.branchId ?? '';
    final snapshotAddress = snapshotItems.isNotEmpty
        ? snapshotItems.first.branchAddress
        : '';
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

    if (GoRouter.maybeOf(context) != null) {
      context.pushReplacement(
        '/reservation-submitted',
        extra: ReservationSubmittedArgs(
          reservationId: result.reservationId,
          referenceNo: result.referenceNo,
          branchId: snapshotBranchId,
          pharmacyName: snapshotPharmacy,
          branchName: snapshotBranch,
          branchAddress: snapshotAddress,
          items: snapshotItems,
          totalAmount: snapshotTotal,
        ),
      );
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReservationSubmittedScreen(
          reservationId: result.reservationId,
          referenceNo: result.referenceNo,
          branchId: snapshotBranchId,
          pharmacyName: snapshotPharmacy,
          branchName: snapshotBranch,
          branchAddress: snapshotAddress,
          items: snapshotItems,
          totalAmount: snapshotTotal,
        ),
      ),
    );
  }

  void _openPharmacy(CustomerCart cart) {
    final branchId = cart.branchId;
    if (branchId == null) return;
    final name = Uri.encodeComponent(cart.pharmacyName ?? '');
    if (GoRouter.maybeOf(context) != null) {
      context.push('/pharmacies/$branchId?name=$name');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PharmacyDetailsScreen(
          branchId: branchId,
          initialTitle: cart.pharmacyName,
        ),
      ),
    );
  }

  Future<void> _getDirections(CustomerCart cart) async {
    final branchId = cart.branchId;
    if (branchId == null) return;

    final branch = await ref.read(pharmacyDetailProvider(branchId).future);
    if (!mounted) return;

    final hasCoords = branch != null &&
        (branch.latitude != 0 || branch.longitude != 0);
    final args = DirectionsArgs(
      pharmacyName: cart.pharmacyName ?? '',
      branchName: cart.branchName ?? '',
      address: cart.branchAddress ?? '',
      destination: hasCoords
          ? LatLng(branch.latitude, branch.longitude)
          : const LatLng(10.7202, 122.5621),
    );

    if (GoRouter.maybeOf(context) != null) {
      context.push('/directions', extra: args);
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectionsScreen(
          pharmacyName: args.pharmacyName,
          branchName: args.branchName,
          address: args.address,
          destination: args.destination,
        ),
      ),
    );
  }

  void _changePharmacy() {
    ref.read(customerTabProvider.notifier).select(0);
    if (GoRouter.maybeOf(context) != null) {
      context.go('/home');
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _browseMedicines() {
    if (widget.onBrowseMedicines != null) {
      widget.onBrowseMedicines!();
      return;
    }
    ref.read(customerTabProvider.notifier).select(1);
    if (GoRouter.maybeOf(context) != null) {
      context.go('/home');
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    final hasItems = cartAsync.value?.isNotEmpty == true;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      bottomNavigationBar: const CustomerBottomChrome(),
      appBar: AppBar(
        title: CustomerLocationAppBarTitle(
          heading: hasItems ? null : 'Your Cart',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (hasItems)
            TextButton(
              onPressed: _busy ? null : () => _openPharmacy(cartAsync.value!),
              child: const Text(
                'View Details',
                style: TextStyle(color: AppColors.danger),
              ),
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
                  return _EmptyCartView(onBrowseMedicines: _browseMedicines);
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const PageStorageKey<String>('customer-cart'),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          customerBottomChromeScrollPadding(
                            context,
                            showBasket: false,
                          ),
                        ),
                        children: [
                          // Selected single-branch banner
                          _BranchBanner(
                            cart: cart,
                            onGetDirections: () => _getDirections(cart),
                            onChangePharmacy: _changePharmacy,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Line items
                          ...cart.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _CartItemCard(
                                item: item,
                                busy: _updatingMedicineId == item.medicineId,
                                onDecrement: () => _setItemQuantity(
                                  item.medicineId,
                                  item.quantity - 1,
                                ),
                                onIncrement: () => _setItemQuantity(
                                  item.medicineId,
                                  item.quantity + 1,
                                ),
                                onRemove: () => _setItemQuantity(
                                  item.medicineId,
                                  0,
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
  const _BranchBanner({
    required this.cart,
    required this.onGetDirections,
    required this.onChangePharmacy,
  });

  final CustomerCart cart;
  final VoidCallback onGetDirections;
  final VoidCallback onChangePharmacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.primaryLight,
                  child: const Icon(
                    Icons.local_pharmacy,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.pharmacyName ?? '',
                      style: const TextStyle(
                        fontSize: 16,
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onGetDirections,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Get Directions'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onChangePharmacy,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Change Pharmacy'),
                ),
              ),
            ],
          ),
        ],
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
                TextButton(
                  onPressed: busy ? null : onRemove,
                  child: const Text(
                    'Remove',
                    style: TextStyle(color: AppColors.danger),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
      color: AppColors.primaryLight,
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
                const Text(
                  'Estimated Total',
                  style: TextStyle(
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
                  : const Text('Continue to Reservation'),
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