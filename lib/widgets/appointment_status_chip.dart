import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/appointment_status.dart';
import 'status_chip.dart';

/// Displays a consistent appointment status label on patient and doctor
/// appointment screens, using both an icon and a text label.
class AppointmentStatusChip extends StatelessWidget {
  /// Creates an appointment status chip.
  const AppointmentStatusChip({
    super.key,
    required this.status,
  });

  final AppointmentStatus status;

  /// Returns the color associated with the appointment status.
  Color get _color {
    switch (status) {
      case AppointmentStatus.confirmed:
        return AppColors.success;
      case AppointmentStatus.pending:
        return AppColors.warning;
      case AppointmentStatus.cancelled:
        return AppColors.danger;
      case AppointmentStatus.done:
        return AppColors.success;
      case AppointmentStatus.noShow:
        return AppColors.danger;
    }
  }

  /// Returns the icon associated with the appointment status.
  IconData get _icon {
    switch (status) {
      case AppointmentStatus.confirmed:
        return Icons.check_circle_rounded;
      case AppointmentStatus.pending:
        return Icons.schedule_rounded;
      case AppointmentStatus.cancelled:
        return Icons.cancel_rounded;
      case AppointmentStatus.done:
        return Icons.task_alt_rounded;
      case AppointmentStatus.noShow:
        return Icons.event_busy_rounded;
    }
  }

  /// Builds the shared status chip.
  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: status.label,
      color: _color,
      icon: _icon,
    );
  }
}
