import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'status_badge.dart';

// How long ago a pharmacy confirmed this stock, matching the mock labels
String stockUpdatedAgo(DateTime confirmed) {
  final diff = DateTime.now().difference(confirmed.toLocal());
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    return '$minutes ${minutes == 1 ? 'min' : 'mins'} ago';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return '$hours ${hours == 1 ? 'hr' : 'hrs'} ago';
  }
  final days = diff.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

String stockStatusLabel(String? availability) {
  return switch (availability) {
    'available' => 'In Stock',
    'low_stock' => 'Low Stock',
    'unavailable' => 'Out of Stock',
    _ => 'Unconfirmed',
  };
}

// In-store medicine box: brand, rx, generic/dosage/form, price, update, stock
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
    this.stockConfirmedAt,
    this.onTap,
  });

  final String name;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String? priceText;
  final String? availability;
  final bool requiresPrescription;
  final DateTime? stockConfirmedAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _MedicineThumb(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        requiresPrescription
                            ? const StatusBadge(
                                'Rx required',
                                tone: BadgeTone.info,
                              )
                            : const StatusBadge(
                                'No Rx needed',
                                tone: BadgeTone.success,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _LabeledValue(label: 'Generic', value: genericName),
                  _LabeledValue(label: 'Dosage', value: strength),
                  _LabeledValue(label: 'Form', value: dosageForm),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _LabeledValue(label: 'Price per Unit', value: priceText ?? '—'),
                  _LabeledValue(
                    label: 'Last Updated',
                    value: stockConfirmedAt == null
                        ? '—'
                        : stockUpdatedAgo(stockConfirmedAt!),
                  ),
                  _LabeledValue(
                    label: 'Stock Status',
                    value: stockStatusLabel(availability),
                  ),
                  if (onTap != null)
                    IconButton(
                      tooltip: 'Add $name',
                      onPressed: onTap,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.add, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineThumb extends StatelessWidget {
  const _MedicineThumb();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 48,
        height: 48,
        color: AppColors.primaryLight,
        child: const Icon(Icons.medication, color: AppColors.primary),
      ),
    );
  }
}
