import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/status_badge.dart';

// Card showing medicine details
class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    this.priceText,
    this.availability,
    this.requiresPrescription = false,
    this.pharmacyCount,
    this.onTap,
    this.actionLabel,
    this.onAction,
  });

  // Medicine brand/commercial name
  final String name;

  // Active chemical/generic name
  final String genericName;

  final String strength;
  final String dosageForm;
  final String? priceText;
  final String? availability;
  final bool requiresPrescription;

  // Number of pharmacies carrying this item
  final int? pharmacyCount;

  // Called when the card body is tapped
  final VoidCallback? onTap;

  // Optional trailing action (prototype "Add to Cart")
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            genericName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (requiresPrescription) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusBadge.rx(),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$strength · $dosageForm',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (availability != null)
                            StatusBadge.availability(availability!)
                          else if (pharmacyCount != null)
                            Text(
                              '$pharmacyCount ${pharmacyCount == 1 ? 'pharmacy' : 'pharmacies'} nearby',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          if (priceText != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              priceText!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(116, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
