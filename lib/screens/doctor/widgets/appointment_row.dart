import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/appointment_status.dart';
import '../../../models/doctor_dashboard_data.dart';
import '../../../widgets/appointment_status_chip.dart';
import '../../../widgets/h360_card.dart';

/// One row in Today's Appointments: time, patient, reason and status.
class AppointmentRow extends StatelessWidget {
  const AppointmentRow({super.key, required this.appointment, required this.onTap});

  final DoctorAppointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final cancelled = a.status == AppointmentStatus.cancelled;
    final mode = a.isVideo ? 'Video' : 'In person';

    return H360Card(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Time
          SizedBox(
            width: 84,
            child: Text(
              a.time,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: cancelled ? AppColors.textMuted : AppColors.navy,
              ),
            ),
          ),
          // Patient and reason
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cancelled ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.reason} · $mode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status label
          AppointmentStatusChip(status: a.status),
        ],
      ),
    );
  }
}
