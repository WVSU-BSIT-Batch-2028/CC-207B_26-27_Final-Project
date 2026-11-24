import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/reservation.dart';
import '../../../providers/cart_providers.dart';
import '../../../providers/customer_nav_provider.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../providers/reservation_providers.dart';
import '../../../services/cart_service.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../cart/cart_screen.dart';
import '../pharmacy/directions_screen.dart';

// Customer reservation details screen with live status timeline & pickup code
// Matches wireframes P-20, P-21, P-26, and P-27
class ReservationDetailsScreen extends ConsumerWidget {
  const ReservationDetailsScreen({
    super.key,
    required this.reservationId,
  });

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(reservationDetailProvider(reservationId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            ref.read(customerTabProvider.notifier).select(2);
            context.go('/home');
          },
        ),
        title: const CustomerLocationAppBarTitle(
          heading: 'Reservation Details',
          icon: Icons.receipt_long_outlined,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(myReservationsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: AsyncView<CustomerReservation?>(
        value: detailAsync,
        onRetry: () => ref.read(myReservationsProvider.notifier).refresh(),
        builder: (reservation) {
          if (reservation == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Reservation not found.',
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(myReservationsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _HeaderCard(reservation: reservation),
                const SizedBox(height: AppSpacing.md),
                _PickupCodeOrNoticeCard(reservation: reservation),
                const SizedBox(height: AppSpacing.md),
                _PharmacyCard(reservation: reservation),
                const SizedBox(height: AppSpacing.md),
                _ItemsCard(reservation: reservation),
                if (reservation.prescriptions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _PrescriptionsCard(reservation: reservation),
                ],
                const SizedBox(height: AppSpacing.md),
                _TimelineCard(reservation: reservation),
                if (reservation.status == ReservationStatus.pending) ...[
                  const SizedBox(height: AppSpacing.md),
                  _CancelReservationCard(reservationId: reservation.id),
                ],
                if (_canReorder(reservation.status)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ReorderCard(reservation: reservation),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}




class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  Widget build(BuildContext context) {
    final submittedLabel = DateFormat(
      'MMM d, yyyy · h:mm a',
    ).format(reservation.submittedAt.toLocal());
    final expiresLabel = DateFormat(
      'MMM d, yyyy · h:mm a',
    ).format(reservation.expiresAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'REFERENCE NUMBER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                StatusBadge.reservation(reservation.status.dbValue),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reservation.referenceNo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy reference number',
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: reservation.referenceNo),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reference number copied.'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Placed on $submittedLabel',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (reservation.status.isActive) ...[
              const SizedBox(height: 2),
              Text(
                'Valid until $expiresLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}




class _PickupCodeOrNoticeCard extends StatelessWidget {
  const _PickupCodeOrNoticeCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  Widget build(BuildContext context) {
    final code = reservation.fullPickupCode;

    // Confirmed or Ready for Pickup: show MT-MMDDYY-XXXX pickup code
    // Ready for Pickup: show pickup code — the medicine is prepared
    if (reservation.status == ReservationStatus.readyForPickup && code != null) {
      return Card(
        color: AppColors.primaryLight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_2_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Text(
                    'READY FOR PICKUP · PICKUP CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy pickup code',
                    icon: const Icon(
                      Icons.copy_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pickup code copied.')),
                      );
                    },
                  ),
                ],
              ),
              Text(
                reservation.hasRx
                    ? 'Show this code at the pharmacy counter and bring your original physical prescription.'
                    : 'Show this code at the pharmacy counter to collect your reservation.',
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ],
          ),
        ),
      );
    }

    // Confirmed: pharmacy accepted — medicine is being prepared, no code yet
    if (reservation.status == ReservationStatus.confirmed) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.info,
                size: 20,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reservation confirmed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'The pharmacy is preparing your medicine. Your pickup code will appear here once it is ready for collection.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pending: waiting for pharmacy review
    if (reservation.status == ReservationStatus.pending) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Waiting for the pharmacy to confirm your reservation. You will be notified when it is confirmed and again when your medicine is ready for pickup.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Rejected or Cancelled: display reason from pharmacy
    if (reservation.status == ReservationStatus.rejected ||
        reservation.status == ReservationStatus.cancelled) {
      final isRejected = reservation.status == ReservationStatus.rejected;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    isRejected
                        ? 'Reason for rejection'
                        : 'Reason for cancellation',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                (reservation.closedReason ?? '').isNotEmpty
                    ? reservation.closedReason!
                    : 'No reason provided by the pharmacy.',
                style: const TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ],
          ),
        ),
      );
    }

    // Expired
    if (reservation.status == ReservationStatus.expired) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_busy_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'This reservation expired after 7 days without pickup and any held stock was released.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Completed
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.primary,
              size: 20,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Order picked up and completed. Thank you!',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class _PharmacyCard extends ConsumerWidget {
  const _PharmacyCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacyAsync =
        ref.watch(pharmacyDetailProvider(reservation.branchId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        'PICKUP BRANCH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reservation.pharmacyName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (reservation.branchName.isNotEmpty)
                        Text(
                          reservation.branchName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      if (reservation.branchAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          reservation.branchAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (reservation.status == ReservationStatus.confirmed ||
                reservation.status == ReservationStatus.readyForPickup ||
                reservation.status == ReservationStatus.completed)
              OutlinedButton.icon(
                onPressed: () {
                  final branch = pharmacyAsync.value;
                  final args = DirectionsArgs(
                    pharmacyName: reservation.pharmacyName,
                    branchName: reservation.branchName,
                    address: reservation.branchAddress,
                    destination: LatLng(
                      (branch != null && branch.latitude != 0)
                          ? branch.latitude
                          : 10.7202,
                      (branch != null && branch.longitude != 0)
                          ? branch.longitude
                          : 122.5621,
                    ),
                  );
                  if (GoRouter.maybeOf(context) != null) {
                    context.push('/directions', extra: args);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DirectionsScreen(
                        pharmacyName: args.pharmacyName,
                        branchName: args.branchName,
                        address: args.address,
                        destination: args.destination,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Get directions'),
              ),
          ],
        ),
      ),
    );
  }
}




class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESERVED MEDICINES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...reservation.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${item.brandName} × ${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              if (item.isRx) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const StatusBadge.rx(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.genericName} · ${item.strength} · ${item.dosageForm}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            item.formattedUnitPrice,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      item.formattedLineTotal,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total reported amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  reservation.formattedTotal,
                  style: const TextStyle(
                    fontSize: 18,
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




class _PrescriptionsCard extends StatelessWidget {
  const _PrescriptionsCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATTACHED PRESCRIPTIONS (${reservation.prescriptions.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...reservation.prescriptions.map(
              (rx) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  rx.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(rx.displayId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  Widget build(BuildContext context) {
    final events = reservation.statusHistory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STATUS TIMELINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (events.isEmpty)
              const Text(
                'No status updates yet.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              )
            else
              ...List.generate(events.length, (index) {
                final event = events[index];
                final isLast = index == events.length - 1;
                final timeLabel = DateFormat(
                  'MMM d, yyyy · h:mm a',
                ).format(event.createdAt.toLocal());

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLast
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: AppColors.border,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: isLast ? 0 : AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.toStatus.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isLast
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if ((event.reason ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: ${event.reason}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CancelReservationCard extends ConsumerStatefulWidget {
  const _CancelReservationCard({required this.reservationId});

  final String reservationId;

  @override
  ConsumerState<_CancelReservationCard> createState() =>
      _CancelReservationCardState();
}

class _CancelReservationCardState extends ConsumerState<_CancelReservationCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text(
          'The pharmacy will no longer prepare this reservation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep reservation'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(myReservationsProvider.notifier)
          .cancelMyReservation(widget.reservationId);
      if (!mounted) return;
      ref.invalidate(reservationDetailProvider(widget.reservationId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyCustomerCancelError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _cancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cancel_outlined),
      label: const Text('Cancel reservation'),
    );
  }
}

String _friendlyCustomerCancelError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('customer_cancel_reservation') &&
      message.contains('schema cache')) {
    return 'Cancel is not available on the server yet. Try again in a minute after a refresh.';
  }
  if (message.contains('only pending reservations')) {
    return 'This reservation can no longer be cancelled.';
  }
  return 'Could not cancel reservation. Try again.';
}

bool _canReorder(ReservationStatus status) {
  return status == ReservationStatus.completed ||
      status == ReservationStatus.cancelled ||
      status == ReservationStatus.rejected ||
      status == ReservationStatus.expired;
}

class _ReorderCard extends ConsumerStatefulWidget {
  const _ReorderCard({required this.reservation});

  final CustomerReservation reservation;

  @override
  ConsumerState<_ReorderCard> createState() => _ReorderCardState();
}

class _ReorderCardState extends ConsumerState<_ReorderCard> {
  bool _busy = false;

  Future<void> _handleReorder() async {
    setState(() => _busy = true);
    try {
      final cart = ref.read(cartProvider).value;
      var replaceBranch = false;
      if (cart != null &&
          cart.branchId != null &&
          cart.branchId != widget.reservation.branchId &&
          cart.items.isNotEmpty) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Start a new cart?'),
            content: Text(
              'Your cart already contains items from ${cart.pharmacyName ?? "another pharmacy"}. '
              'Replace your current cart with items from ${widget.reservation.pharmacyName}?',
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
        if (replace != true) {
          setState(() => _busy = false);
          return;
        }
        replaceBranch = true;
      }

      final notifier = ref.read(cartProvider.notifier);
      if (replaceBranch) {
        await notifier.clearCart();
      }

      var itemsAdded = 0;
      for (final item in widget.reservation.items) {
        final outcome = await notifier.addItem(
          branchId: widget.reservation.branchId,
          medicineId: item.medicineId,
          quantity: item.quantity,
          replaceBranch: false,
        );
        if (outcome == AddToCartOutcome.added) {
          itemsAdded++;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reordered $itemsAdded ${itemsAdded == 1 ? "item" : "items"} from ${widget.reservation.pharmacyName}.',
          ),
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

      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CartScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'REORDER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Add all items from this reservation back into your cart.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _busy ? null : _handleReorder,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.replay_outlined),
              label: Text(_busy ? 'Reordering...' : 'Reorder items'),
            ),
          ],
        ),
      ),
    );
  }
}



