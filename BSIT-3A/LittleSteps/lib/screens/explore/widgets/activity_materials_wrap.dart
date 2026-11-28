import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../utils/material_labels.dart';
import 'explore_activity_card.dart';

/// Wrapped row of normalized [MaterialPill] badges for activity cards and details.
class MaterialPillsWrap extends StatelessWidget {
  /// Creates a [MaterialPillsWrap] for [materials].
  const MaterialPillsWrap({super.key, required this.materials});

  /// Raw activity materials list before normalization.
  final List<String> materials;

  @override
  Widget build(BuildContext context) {
    final labels = displayActivityMaterials(materials);
    return Wrap(
      spacing: AppSpacing.space8,
      runSpacing: AppSpacing.space4,
      children: labels.map((label) => MaterialPill(label: label)).toList(),
    );
  }
}

/// Numbered list of play instructions styled with consistent spacing and counters.
class NumberedStepsList extends StatelessWidget {
  /// Creates a [NumberedStepsList] for [steps].
  const NumberedStepsList({super.key, required this.steps, this.textStyle});

  /// Sequential caregiver instructions to render.
  final List<String> steps;

  /// Optional override typography applied to step text and counters.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = textStyle ?? Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ',
                  style: effectiveStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
                Expanded(child: Text(steps[i], style: effectiveStyle)),
              ],
            ),
          ),
      ],
    );
  }
}
