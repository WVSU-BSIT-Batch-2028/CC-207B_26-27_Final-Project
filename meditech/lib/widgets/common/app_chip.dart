import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Tappable filter chip for categories, dosage forms, and sorting
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.onDeleted,
  });

  // Text shown on the chip
  final String label;

  // Whether this filter is currently active
  final bool selected;

  // Called when the user taps the chip
  final ValueChanged<bool>? onSelected;

  // Optional icon before the label
  final IconData? icon;

  // Optional delete action to clear this filter
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textMuted,
            )
          : null,
      onDeleted: onDeleted,
      deleteIconColor: selected ? AppColors.primary : AppColors.textMuted,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.text,
      ),
      backgroundColor: AppColors.neutralLight,
      selectedColor: AppColors.primaryLight,
      checkmarkColor: AppColors.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1,
        ),
      ),
    );
  }
}