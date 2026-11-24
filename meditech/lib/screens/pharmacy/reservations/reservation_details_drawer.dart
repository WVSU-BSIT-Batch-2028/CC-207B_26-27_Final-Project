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
    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: 'Confirm reservation ${res.referenceNo}?',
      targetName: res.hasRx
          ? 'Rx items included — verify the uploaded prescription before confirming.'
          : null,
      consequences: [
        'Stock will be held for ${res.customerName} until pickup, cancellation, or expiry.',
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

  // Mark reservation ready for pickup — generates the pickup code (Ph-18)
  Future<void> _handleMarkReady(BranchReservation res) async {
    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: 'Mark ready for pickup?',
      targetName: res.referenceNo,
      consequences: [
        'The pickup code is generated and sent to ${res.customerName}.',
        'Place the prepared medicine at the counter before confirming.',
      ],
      confirmLabel: 'Mark ready',
    );

    if (confirmed == true && mounted) {
      setState(() => _isBusy = true);
      try {
        await ref.read(branchReservationsProvider.notifier).markReady(res.id);
        ref.invalidate(selectedReservationDetailProvider);
      } catch (e) {
        await _showActionError(e, 'mark this reservation ready');
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
            'Medicines are handed to ${res.customerName} and stock is deducted.',
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
    String? url;
    try {
      final service = ref.read(branchReservationServiceProvider);
      url = await service.getPrescriptionUrl(
        prescription.id,
        reservationId: widget.reservationId,
      );
    } catch (e) {
      await _showActionError(e, 'load the prescription');
      if (mounted) setState(() => _isBusy = false);
      return;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }

    if (!mounted) return;

    final isPdf = prescription.mimeType.contains('pdf');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Prescription · $refNo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                Text(
                  prescription.displayId,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: url == null
                        ? _PrescriptionUnavailable(isPdf: isPdf)
                        : isPdf
                            ? _PdfPreview(url: url, displayId: prescription.displayId)
                            : InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 5.0,
                                child: Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (_, _, _) =>
                                      const _PrescriptionUnavailable(isPdf: false),
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Verify doctor, date, medicine name, and dosage before confirming.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
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
                        // Status hint
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.info),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.info),
                              SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Confirmed — medicine is being prepared. Mark ready when it is on the counter and the pickup code has been given to the patient.',
                                  style: TextStyle(fontSize: 12, color: AppColors.info),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Mark ready action button
                        ElevatedButton(
                          onPressed: _isBusy
                              ? null
                              : () => _handleMarkReady(reservation),
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
                          final isPdf = rx.mimeType.contains('pdf');
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Thumbnail area
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(7),
                                  ),
                                  child: isPdf
                                      ? Container(
                                          height: 120,
                                          color: AppColors.background,
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf_outlined,
                                                size: 48,
                                                color: AppColors.danger,
                                              ),
                                              SizedBox(height: AppSpacing.xs),
                                              Text(
                                                'PDF document',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : _PrescriptionThumbnail(
                                          prescription: rx,
                                          reservationId: widget.reservationId,
                                        ),
                                ),
                                // Footer row: ID + View Full Size button
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.description_outlined,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rx.displayId,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Text(
                                              'Verify doctor, date, medicine, and dosage.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton.icon(
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
                                        icon: const Icon(Icons.open_in_full, size: 14),
                                        label: const Text('View Full Size'),
                                      ),
                                    ],
                                  ),
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

// Loads and shows an image thumbnail for a prescription inline in the drawer.
// Fetches a signed URL lazily on first build.
class _PrescriptionThumbnail extends ConsumerStatefulWidget {
  const _PrescriptionThumbnail({
    required this.prescription,
    required this.reservationId,
  });

  final BranchPrescription prescription;
  final String reservationId;

  @override
  ConsumerState<_PrescriptionThumbnail> createState() =>
      _PrescriptionThumbnailState();
}

class _PrescriptionThumbnailState
    extends ConsumerState<_PrescriptionThumbnail> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchUrl();
  }

  Future<void> _fetchUrl() async {
    try {
      final service = ref.read(branchReservationServiceProvider);
      final url = await service.getPrescriptionUrl(
        widget.prescription.id,
        reservationId: widget.reservationId,
      );
      if (mounted) setState(() { _url = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error || _url == null) {
      return const _PrescriptionUnavailable(isPdf: false);
    }
    return Image.network(
      _url!,
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, _, _) =>
          const _PrescriptionUnavailable(isPdf: false),
    );
  }
}

// Shown when a prescription image cannot be loaded.
class _PrescriptionUnavailable extends StatelessWidget {
  const _PrescriptionUnavailable({required this.isPdf});

  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_outlined : Icons.broken_image_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Could not load image',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// Shown in the full-size dialog for PDF prescriptions.
class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.url, required this.displayId});

  final String url;
  final String displayId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            size: 72,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            displayId,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'PDF prescriptions cannot be previewed inline.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Ask the customer to show the original document at pickup.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
