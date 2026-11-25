import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/cart.dart';
import '../../../providers/customer_nav_provider.dart';
import '../../../providers/reservation_providers.dart';
import '../../../widgets/common/branch_storefront_thumb.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/common/medicine_id_thumb.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Values carried to the confirmation route after Continue to Reservation
class ReservationSubmittedArgs {
  const ReservationSubmittedArgs({
    required this.reservationId,
    required this.referenceNo,
    required this.branchId,
    required this.pharmacyName,
    required this.branchName,
    required this.branchAddress,
    required this.items,
    required this.totalAmount,
  });

  final String reservationId;
  final String referenceNo;
  final String branchId;
  final String pharmacyName;
  final String branchName;
  final String branchAddress;
  final List<CartItem> items;
  final double totalAmount;
}

// Confirmation screen shown right after placing a reservation (wireframe P-19)
class ReservationSubmittedScreen extends ConsumerStatefulWidget {
  const ReservationSubmittedScreen({
    super.key,
    required this.reservationId,
    required this.referenceNo,
    required this.branchId,
    required this.pharmacyName,
    required this.branchName,
    required this.branchAddress,
    required this.items,
    required this.totalAmount,
  });

  final String reservationId;
  final String referenceNo;
  final String branchId;
  final String pharmacyName;
  final String branchName;
  final String branchAddress;
  final List<CartItem> items;
  final double totalAmount;

  @override
  ConsumerState<ReservationSubmittedScreen> createState() =>
      _ReservationSubmittedScreenState();
}

String _friendlyCancelError(Object error) {
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

class _ReservationSubmittedScreenState
    extends ConsumerState<ReservationSubmittedScreen> {
  bool _cancelling = false;
  bool _cancelled = false;

  Future<void> _confirmCancel() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text(
          'The pharmacy will no longer prepare this reservation. You can place a new one anytime.',
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

    setState(() => _cancelling = true);
    try {
      await ref
          .read(myReservationsProvider.notifier)
          .cancelMyReservation(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _cancelled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled.')),
      );
      ref.read(customerTabProvider.notifier).select(2);
      if (GoRouter.maybeOf(context) != null) {
        context.go('/home');
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyCancelError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const CustomerLocationAppBarTitle(
          heading: 'Reservation Submitted',
          icon: Icons.check_circle_outline,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Reservation submitted',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Your pickup code will be generated after the pharmacy confirms your reservation.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
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
                        StatusBadge.reservation(
                          _cancelled ? 'cancelled' : 'pending',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.referenceNo,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy reference number',
                          icon: const Icon(Icons.copy_outlined, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.referenceNo),
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
                    const Divider(height: AppSpacing.lg),
                    Row(
                      children: [
                        BranchStorefrontThumb(
                          branchId: widget.branchId,
                          size: 44,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.pharmacyName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              if (widget.branchName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.branchName,
                                  style: const TextStyle(
                                    fontSize: 13,
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
                    ...widget.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MedicineIdThumb(
                              medicineId: item.medicineId,
                              size: 36,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${item.brandName} × ${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            Text(
                              item.formattedLineTotal,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '₱${widget.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _cancelling || _cancelled ? null : _confirmCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancel reservation'),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () {
                ref.read(customerTabProvider.notifier).select(0);
                context.go('/home');
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(customerTabProvider.notifier).select(1);
                context.go('/home');
              },
              icon: const Icon(Icons.search),
              label: const Text('Search Again'),
            ),
          ],
        ),
      ),
    );
  }
}