import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/medication_dose.dart';
import '../../../../widgets/h360_card.dart';

/// Today's doses with tap-to-mark-as-taken and a progress bar.
class MedicationChecklist extends StatelessWidget {
  const MedicationChecklist({super.key, required this.doses, required this.onToggle});

  final List<MedicationDose> doses;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (doses.isEmpty) {
      return H360Card(
        child: Row(
          children: [
            Icon(Icons.medication_outlined, color: AppColors.textMuted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No medications scheduled for today.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final taken = doses.where((d) => d.taken).length;
    return H360Card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$taken of ${doses.length} taken',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const Spacer(),
              if (taken == doses.length)
                const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: taken / doses.length,
              minHeight: 8,
              backgroundColor: AppColors.skeleton,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          for (final dose in doses) _DoseRow(dose: dose, onTap: () => onToggle(dose.id)),
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.onTap});
  final MedicationDose dose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: dose.taken,
      label: '${dose.name} ${dose.dosage} at ${dose.time}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dose.taken ? AppColors.success : Colors.transparent,
                  border: Border.all(
                    color: dose.taken ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                ),
                child: dose.taken
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dose.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: dose.taken ? TextDecoration.lineThrough : null,
                        color: dose.taken ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                    Text(dose.dosage, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Text(dose.time, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
