import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cart.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Confirmation screen shown right after placing a reservation (wireframe P-19)
class ReservationSubmittedScreen extends StatelessWidget {
  const ReservationSubmittedScreen({
    super.key,
    required this.reservationId,
    required this.referenceNo,
    required this.pharmacyName,
    required this.branchName,
    required this.items,
    required this.totalAmount,
    this.onViewReservation,
    this.onBackToHome,
  });

  final String reservationId;
  final String referenceNo;
  final String pharmacyName;
  final String branchName;
  final List<CartItem> items;
  final double totalAmount;
  final VoidCallback? onViewReservation;
  final VoidCallback? onBackToHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Reservation Submitted'),
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
                        StatusBadge.reservation('pending'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            referenceNo,
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
                            Clipboard.setData(ClipboardData(text: referenceNo));
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
                    Text(
                      pharmacyName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (branchName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        branchName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                          '₱${totalAmount.toStringAsFixed(2)}',
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
            FilledButton(
              onPressed: () {
                if (onViewReservation != null) {
                  onViewReservation!();
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('View Reservation'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () {
                if (onBackToHome != null) {
                  onBackToHome!();
                  return;
                }
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}