import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import 'h360_card.dart';

/// A card with a tinted icon box on the left and any content on the right.
///
/// Shared by the prescription screens (details and history details) so every
/// info card looks identical.
class PrescriptionInfoCard extends StatelessWidget {
  const PrescriptionInfoCard({
    super.key,
    required this.icon,
    required this.children,
  });

  /// Icon shown in the box on the left.
  final IconData icon;

  /// Content stacked vertically on the right (usually Text widgets).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return H360Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          // Expanded stops long text from overflowing the card.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
