import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/branch_reservation.dart';
import '../../../providers/branch_reservation_providers.dart';
import '../../../providers/pharmacy_staff_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../utils/friendly_error.dart';
import '../../../widgets/theme/app_spacing.dart';

// Slide-in reservation details drawer for pharmacy tablets (Ph-14, Ph-17, Ph-18, Ph-37)
class ReservationDetailsDrawer extends ConsumerStatefulWidget {
  const ReservationDetailsDrawer({
    super.key,
    required this.reservationId,
    this.onClose,
  });

  final String reservationId;
  final VoidCallback? onClose;

  @override
  ConsumerState<ReservationDetailsDrawer> createState() =>
      _ReservationDetailsDrawerState();
}

class _ReservationDetailsDrawerState
    extends ConsumerState<ReservationDetailsDrawer> {
  final TextEditingController _codeController = TextEditingController();
  bool _codeError = false;
  bool _isBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _showActionError(Object error, String action) async {
    if (!mounted) return;
    await showFriendlyErrorDialog(context, error, action: action);
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) {
      return 'Today, $timeStr';
    }
    return '${DateFormat('MMM d').format(dt)}, $timeStr';
  }

  // Confirm reservation modal (Ph-15)
  Future<void> _handleConfirm(BranchReservation res) async {
    final medicineDesc = res.items
        .map((i) => '${i.brandName} × ${i.quantity}')
        .join(', ');

    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: 'Confirm ${res.referenceNo}?',
      targetName: '${res.customerName} · $medicineDesc',
      consequences: [
        'Holds $medicineDesc from your stock until pickup, cancellation, or expiry.',
        'Generates a pickup code and notifies ${res.customerName}.',
        if (res.hasRx)
          'Confirms that you checked the uploaded prescription.',
      ],
      confirmLabel: 'Confirm reservation',
    );

    if (confirmed == true && mounted) {
      setState(() => _isBusy = true);
      try {
        await ref
            .read(branchReservationsProvider.notifier)
            .confirm(res.id);
        ref.invalidate(selectedReservationDetailProvider);
      } catch (e) {
        await _showActionError(e, 'confirm this reservation');
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
    }
  }

  // Reject reservation reason dialog (Ph-16)
  Future<void> _handleReject(BranchReservation res) async {
    final reason = await showTabletReasonDialog(
      context: context,
      title: 'Reject reservation',
      explanation:
          'The patient is notified, and no stock is held. The patient sees your reason.',
      placeholder:
          'e.g. The prescription image is unclear. Please upload a clearer photo.',
      actionLabel: 'Reject',
      isDanger: true,
    );

    if (reason != null && mounted) {
      setState(() => _isBusy = true);
      try {
        await ref
            .read(branchReservationsProvider.notifier)
            .reject(res.id, reason);
        ref.invalidate(selectedReservationDetailProvider);
      } catch (e) {
        await _showActionError(e, 'reject this reservation');
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
    }
  }

  // Cancel reservation reason dialog
  Future<void> _handleCancel(BranchReservation res) async {
    final reason = await showTabletReasonDialog(
      context: context,
      title: 'Cancel reservation',
      explanation:
          'The patient is notified and any held stock is released back to your inventory.',
      placeholder: 'e.g. Patient called requesting cancellation.',
      actionLabel: 'Cancel reservation',
      isDanger: true,
    );

    if (reason != null && mounted) {
      setState(() => _isBusy = true);
      try {
        await ref
            .read(branchReservationsProvider.notifier)
            .cancel(res.id, reason);
        ref.invalidate(selectedReservationDetailProvider);
      } catch (e) {
        await _showActionError(e, 'cancel this reservation');
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
    }
  }

  // Verify pickup code action (Ph-18, Ph-19)
  Future<void> _handleVerifyCode(BranchReservation res) async {
    final inputCode = _codeController.text.trim();
    if (inputCode.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final isValid = await ref
          .read(branchReservationsProvider.notifier)
          .checkCode(res.id, inputCode);

      setState(() {
        _codeError = !isValid;
      });

      if (isValid && mounted) {
        // Code matches, open Release & Complete confirmation modal (Ph-20)
        final medicineDesc = res.items
            .map((i) => '${i.brandName} × ${i.quantity}')
            .join(', ');

        final completed = await showTabletConfirmDialog(
          context: context,
          title: 'Release medicines and complete?',
          targetName: '${res.customerName} · $medicineDesc',
          consequences: [
            'The code matches ${res.referenceNo}.',
            'Stock is deducted: $medicineDesc.',
            'The reservation is marked Completed and the code can\'t be used again.',
          ],
          confirmLabel: 'Release and complete',
        );

        if (completed == true && mounted) {
          await ref
              .read(branchReservationsProvider.notifier)
              .complete(res.id, inputCode);
          ref.invalidate(selectedReservationDetailProvider);
          _codeController.clear();
        }
      }
    } catch (e) {
      await _showActionError(e, 'verify the pickup code');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // View full size doctor prescription dialog
  Future<void> _viewPrescription(BranchPrescription prescription, String refNo) async {
    setState(() => _isBusy = true);
    try {
      final service = ref.read(branchReservationServiceProvider);
      final url = await service.getPrescriptionUrl(
        prescription.id,
        reservationId: widget.reservationId,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prescription · $refNo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    height: 380,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          prescription.displayId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Path: ${prescription.storagePath}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (url != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            '(Signed access URL generated & logged)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      await _showActionError(e, 'load the prescription');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(selectedReservationDetailProvider);
    final staffProfile = ref.watch(pharmacyStaffProfileProvider).value;
    final canLicenseActions =
        ref.watch(pharmacyCanLicenseReservationsProvider);
    final canCancel = staffProfile?.canCancelReservation ?? false;

    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border),
        ),
      ),
      child: AsyncView<BranchReservation?>(
        value: detailAsync,
        onRetry: () => ref.invalidate(selectedReservationDetailProvider),
        builder: (reservation) {
          if (reservation == null) {
            return const Center(
              child: Text(
                'Reservation not found.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          // Check if any item has insufficient stock (Ph-17)
          final hasInsufficientStock = reservation.items.any((item) {
            final available = item.currentAvailableStock ?? 999;
            return available < item.quantity;
          });

          final cannotReleaseRx =
              reservation.hasRx && !canLicenseActions;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reservation.referenceNo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${reservation.customerName} · requested ${_formatTimestamp(reservation.submittedAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          StatusBadge.reservation(reservation.status),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Drawer Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Action Section (Pending, Confirmed, Ready)
                      if (reservation.isPending) ...[
                        if (!canLicenseActions) ...[
                          _LicenseRequiredBanner(
                            message: reservation.hasRx
                                ? 'Confirming or rejecting needs a verified pharmacist license. '
                                    'Rx items also require a pharmacist to review the prescription.'
                                : 'Confirming or rejecting needs a verified pharmacist license. '
                                    'Ask the pharmacist on duty or sign in as a verified pharmacist.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        // Insufficient stock warning banner (Ph-17)
                        if (hasInsufficientStock) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger),
                            ),
                            child: const Text(
                              'Some items have insufficient shelf stock. Update stock once refilled, or reject with a reason.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Confirm / Reject action buttons (Ph-14, Ph-17)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (_isBusy ||
                                        hasInsufficientStock ||
                                        !canLicenseActions)
                                    ? null
                                    : () => _handleConfirm(reservation),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Confirm reservation'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: (_isBusy || !canLicenseActions)
                                    ? null
                                    : () => _handleReject(reservation),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ] else if (reservation.isConfirmed) ...[
                        // Mark ready action button
                        ElevatedButton(
                          onPressed: _isBusy
                              ? null
                              : () async {
                                  setState(() => _isBusy = true);
                                  try {
                                    await ref
                                        .read(branchReservationsProvider.notifier)
                                        .markReady(reservation.id);
                                    ref.invalidate(
                                        selectedReservationDetailProvider);
                                  } catch (e) {
                                    await _showActionError(
                                      e,
                                      'mark this reservation ready',
                                    );
                                  } finally {
                                    if (mounted) setState(() => _isBusy = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Mark ready for pickup'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: (_isBusy || !canCancel)
                              ? null
                              : () => _handleCancel(reservation),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel reservation'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ] else if (reservation.isReady) ...[
                        // Verify pickup code section (Ph-18, Ph-19, Ph-37)
                        if (cannotReleaseRx) ...[
                          const _LicenseRequiredBanner(
                            message:
                                'This reservation has prescription (Rx) medicines. '
                                'Only a verified licensed pharmacist can release them. '
                                'Ask the pharmacist on duty.',
                          ),
                        ] else ...[
                          const Text(
                            'Verify pickup code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Enter 4-character code',
                                    errorText: _codeError
                                        ? 'This code doesn\'t match the reservation.'
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              ElevatedButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => _handleVerifyCode(reservation),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Verify'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'The patient presents their 4-character pickup code.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: (_isBusy || !canCancel)
                              ? null
                              : () => _handleCancel(reservation),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel reservation'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Medicines section (Ph-14)
                      const Text(
                        'Medicines',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...reservation.items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.brandName} ${item.strength} × ${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₱${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.genericName} · ${item.dosageForm} · ₱${item.unitPrice.toStringAsFixed(2)} / ${item.unitSold} at submission',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (item.currentAvailableStock != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Available now: ${item.currentAvailableStock} ${item.unitSold}s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: (item.currentAvailableStock! <
                                            item.quantity)
                                        ? AppColors.danger
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                      // Total reported amount
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total reported amount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              '₱${reservation.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Uploaded prescription section (Ph-14)
                      if (reservation.prescriptions.isNotEmpty) ...[
                        const Text(
                          'Uploaded prescription',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ...reservation.prescriptions.map((rx) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rx.displayId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Text(
                                        'Check doctor, date, medicine, and dosage before confirming.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _viewPrescription(
                                    rx,
                                    reservation.referenceNo,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('View full size'),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Closed / Rejection reason banner (Ph-26, Ph-28)
                      if (reservation.closedReason != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.danger),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reservation.isRejected
                                    ? 'Rejection reason'
                                    : 'Closed reason',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reservation.closedReason!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Status history section (Ph-14)
                      if (reservation.history.isNotEmpty) ...[
                        const Text(
                          'Status history',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ...reservation.history.map((event) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(
                                    top: 5,
                                    right: AppSpacing.sm,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _statusLabels[event.toStatus] ??
                                            event.toStatus,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        '${_formatTimestamp(event.createdAt)}${event.actorName != null ? ' · ${event.actorName}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const _statusLabels = {
    'pending': 'Submitted',
    'confirmed': 'Confirmed',
    'ready_for_pickup': 'Ready for pickup',
    'completed': 'Completed',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };
}

class _LicenseRequiredBanner extends StatelessWidget {
  const _LicenseRequiredBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
