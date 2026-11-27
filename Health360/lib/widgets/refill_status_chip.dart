import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/refill_request.dart';
import 'status_chip.dart';

/// Coloured label for a refill request. Each status has its own icon AND
/// text, so it never relies on colour alone (AGENTS.md section 5.2).
/// Built on the shared [StatusChip].
class RefillStatusChip extends StatelessWidget {
  const RefillStatusChip({super.key, required this.status});

  final RefillStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RefillStatus.pending:
        return StatusChip(
          label: status.label,
          color: AppColors.warning,
          icon: Icons.schedule_rounded,
        );
      case RefillStatus.approved:
        return StatusChip(
          label: status.label,
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        );
      case RefillStatus.declined:
        return StatusChip(
          label: status.label,
          color: AppColors.danger,
          icon: Icons.cancel_rounded,
        );
    }
  }
}
