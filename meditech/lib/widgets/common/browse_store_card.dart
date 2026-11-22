import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Main Flow home store row: thumbnail, rating, open/registered badges
class BrowseStoreCard extends StatelessWidget {
  const BrowseStoreCard({
    super.key,
    required this.name,
    required this.addressLine,
    this.rating = 4.2,
    this.reviewCount = 40,
    this.isOpen = true,
    this.isRegistered = true,
    this.onTap,
  });

  final String name;
  final String addressLine;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final bool isRegistered;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 64,
                  height: 64,
                  color: isRegistered
                      ? AppColors.primaryLight
                      : AppColors.neutralLight,
                  child: Icon(
                    isRegistered
                        ? Icons.local_pharmacy
                        : Icons.local_pharmacy_outlined,
                    color: isRegistered
                        ? AppColors.primary
                        : AppColors.textMuted,
                    size: 28,
                  ),
                ),
              ),
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
                    if (isRegistered) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Color(0xFFF5A623),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            ' ($reviewCount)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (isRegistered) ...[
                          _Pill(
                            label: isOpen ? 'Open' : 'Closed',
                            background: isOpen
                                ? AppColors.primaryLight
                                : AppColors.dangerLight,
                            foreground: isOpen
                                ? AppColors.primary
                                : AppColors.danger,
                          ),
                          const _Pill(
                            label: 'Registered on MediTech',
                            background: AppColors.primaryLight,
                            foreground: AppColors.primary,
                          ),
                        ] else
                          const _Pill(
                            label: 'Not on MediTech',
                            background: AppColors.neutralLight,
                            foreground: AppColors.textMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
