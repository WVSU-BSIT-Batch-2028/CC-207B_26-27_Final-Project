import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/medicine_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Square medicine pack shot thumbnail resolved by medicineId.
// Falls back to the medication icon if no pack photo is uploaded.
class MedicineIdThumb extends ConsumerWidget {
  const MedicineIdThumb({
    super.key,
    required this.medicineId,
    this.size = 48,
  });

  final String medicineId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(medicineImageUrlByIdProvider(medicineId)).value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _placeholder()
            : Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.primaryLight,
      child: Icon(
        Icons.medication_outlined,
        color: AppColors.primary,
        size: size * 0.45,
      ),
    );
  }
}
