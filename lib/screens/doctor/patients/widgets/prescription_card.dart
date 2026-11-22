import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../models/doctor_prescription.dart';
import '../../../../widgets/h360_card.dart';

/// One card in a patient's prescription list: icon, medicine name and dose,
/// how to take it, a refill (or start) date, and the doctor's note if any.
class PrescriptionCard extends StatelessWidget {
  const PrescriptionCard({super.key, required this.prescription});

  final DoctorPrescription prescription;

  /// "Refill Oct 1, 2026" when a refill is planned, otherwise "Started ...".
  String get _dateLine {
    final p = prescription;
    return p.refillDate != null
        ? 'Refill ${formatLongDate(p.refillDate!)}'
        : 'Started ${formatLongDate(p.startDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final note = p.notes;

    return H360Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tile on the left
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.medication_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name, how to take it, date and note
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  p.instructionText,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  _dateLine,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Note: $note',
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
