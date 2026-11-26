import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// The three filters at the top of Records Overview.
enum RecordFilter {
  all('All'),
  consultations('Consultations'),
  labResults('Lab Results');

  const RecordFilter(this.label);

  /// Text shown on the pill.
  final String label;
}

/// Row of pill buttons (All / Consultations / Lab Results).
///
/// The selected pill is filled navy with white text; the others are outlined.
/// A [Wrap] is used instead of a [Row] so the pills move to a second line
/// instead of overflowing when the text size is Large or Extra large.
class RecordFilterBar extends StatelessWidget {
  const RecordFilterBar({super.key, required this.selected, required this.onChanged});

  /// The filter that is currently active.
  final RecordFilter selected;

  /// Called with the new filter when the user taps a pill.
  final ValueChanged<RecordFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final filter in RecordFilter.values)
          _FilterPill(
            label: filter.label,
            isSelected: filter == selected,
            onTap: () => onChanged(filter),
          ),
      ],
    );
  }
}

/// One pill. Private because only [RecordFilterBar] needs it.
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    // brandNavy stays dark in both light and dark mode, so white text is always readable.
    final fill = isSelected ? AppColors.brandNavy : AppColors.surface;
    final border = isSelected ? AppColors.brandNavy : AppColors.border;
    final textColor = isSelected ? Colors.white : AppColors.navy;

    return Semantics(
      // Lets screen readers say "selected", so the state is not colour-only.
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              // 44 high is a comfortable tap target for older users.
              constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
