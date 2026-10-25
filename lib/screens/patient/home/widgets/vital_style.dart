import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/vital_sign.dart';

/// Colour and icon for each kind of vital (shared by the tile and the detail sheet).
extension VitalTypeStyle on VitalType {
  Color get color {
    switch (this) {
      case VitalType.heartRate:
        return AppColors.heart;
      case VitalType.bloodPressure:
        return AppColors.pressure;
      case VitalType.weight:
        return AppColors.weight;
      case VitalType.sleep:
        return AppColors.sleep;
    }
  }

  IconData get icon {
    switch (this) {
      case VitalType.heartRate:
        return Icons.favorite_rounded;
      case VitalType.bloodPressure:
        return Icons.water_drop_rounded;
      case VitalType.weight:
        return Icons.monitor_weight_rounded;
      case VitalType.sleep:
        return Icons.bedtime_rounded;
    }
  }
}
