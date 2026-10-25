import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/appointment_status.dart';
import 'status_chip.dart';

/// Confirmed (green) / Pending (amber) / Cancelled (red) label.
/// Use this everywhere appointments are listed so the status looks the same
/// for patients and doctors. It has an icon and text, so it never relies on colour alone.
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final AppointmentStatus status;

  Color get _color {
    switch (status) {
      case AppointmentStatus.confirmed:
        return AppColors.success;
      case AppointmentStatus.pending:
        return AppColors.warning;
      case AppointmentStatus.cancelled:
        return AppColors.danger;
    }
  }

  IconData get _icon {
    switch (status) {
      case AppointmentStatus.confirmed:
        return Icons.check_circle_rounded;
      case AppointmentStatus.pending:
        return Icons.schedule_rounded;
      case AppointmentStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: status.label, color: _color, icon: _icon);
}
