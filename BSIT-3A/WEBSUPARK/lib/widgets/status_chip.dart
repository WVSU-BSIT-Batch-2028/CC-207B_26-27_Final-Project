import 'package:flutter/material.dart';
import 'package:websupark/theme/app_colors.dart';

/// The meaning of a status, which decides the chip color.
enum StatusKind { success, warning, danger, neutral }

/// A small rounded label such as "Active", "Pending" or "Resolved".
/// Shared by all three interfaces so statuses always look the same.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.kind = StatusKind.neutral,
  });

  final String label;
  final StatusKind kind;

  // Pale background for each kind, from AppColors.
  Color get _background => switch (kind) {
        StatusKind.success => AppColors.successSoft,
        StatusKind.warning => AppColors.warningSoft,
        StatusKind.danger => AppColors.dangerSoft,
        StatusKind.neutral => AppColors.border,
      };

  // Strong text color for each kind, from AppColors.
  Color get _foreground => switch (kind) {
        StatusKind.success => AppColors.success,
        StatusKind.warning => AppColors.warning,
        StatusKind.danger => AppColors.danger,
        StatusKind.neutral => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}