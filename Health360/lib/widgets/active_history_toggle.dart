import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// The two-button "Active / History" switch shown above prescription lists.
///
/// It holds no state: the screen owns [showingActive] and updates it from
/// [onChanged].
class ActiveHistoryToggle extends StatelessWidget {
  const ActiveHistoryToggle({
    super.key,
    required this.showingActive,
    required this.onChanged,
  });

  /// True when the Active button is the selected one.
  final bool showingActive;

  /// Called with true when Active is tapped, false when History is tapped.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _button('Active', selected: showingActive, value: true)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _button('History', selected: !showingActive, value: false),
        ),
      ],
    );
  }

  /// One button. The selected one is filled navy; the other is outlined.
  Widget _button(
    String label, {
    required bool selected,
    required bool value,
  }) {
    return OutlinedButton(
      onPressed: () => onChanged(value),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.brandNavy : AppColors.surface,
        foregroundColor: selected ? Colors.white : AppColors.navy,
        side: BorderSide(
          color: selected ? AppColors.brandNavy : AppColors.border,
        ),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}
