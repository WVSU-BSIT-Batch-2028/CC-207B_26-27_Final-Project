import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/state_views.dart';
import 'adapted_activity_card.dart';

const List<({String id, String label})> _adjustmentOptions = [
  (id: ActivityAdjustments.shorter, label: 'Shorter (5–10 min)'),
  (id: ActivityAdjustments.easier, label: 'Easier demonstration'),
  (id: ActivityAdjustments.harder, label: 'Extra challenge'),
  (id: ActivityAdjustments.missingMaterial, label: 'Missing a material'),
];

/// Interactive card letting caregivers request and review activity adaptations.
class ActivityAdaptSection extends StatelessWidget {
  /// Creates an [ActivityAdaptSection].
  const ActivityAdaptSection({
    super.key,
    required this.isExpanded,
    required this.selectedAdjustment,
    required this.missingMaterialController,
    required this.isAdapting,
    required this.isScheduling,
    required this.onExpand,
    required this.onCollapse,
    required this.onAdjustmentChanged,
    required this.onMissingMaterialChanged,
    required this.onSubmit,
    required this.onTryAnother,
    this.errorMessage,
    this.adaptedResponse,
    this.onAddAdapted,
  });

  /// Whether the adjustment options form is currently visible.
  final bool isExpanded;

  /// Currently selected adjustment preset identifier.
  final String selectedAdjustment;

  /// Controller for the missing-material text input.
  final TextEditingController missingMaterialController;

  /// Whether an adaptation request is currently loading.
  final bool isAdapting;

  /// Whether scheduling the adapted activity is currently in flight.
  final bool isScheduling;

  /// Callback invoked to expand the adaptation form.
  final VoidCallback onExpand;

  /// Callback invoked to collapse the adaptation form.
  final VoidCallback onCollapse;

  /// Callback invoked when the caregiver chooses a different adjustment preset.
  final ValueChanged<String> onAdjustmentChanged;

  /// Callback invoked when the missing-material text changes.
  final ValueChanged<String> onMissingMaterialChanged;

  /// Callback invoked to submit the adaptation request.
  final VoidCallback onSubmit;

  /// Callback invoked when the caregiver requests another adjustment after a result.
  final VoidCallback onTryAnother;

  /// Optional inline validation or network error message.
  final String? errorMessage;

  /// Adapted variation result, or `null` when none has been generated yet.
  final AdaptActivityResponse? adaptedResponse;

  /// Optional callback scheduling the adapted activity onto Today's plan.
  final VoidCallback? onAddAdapted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = adaptedResponse;
    final headerTitle = isExpanded && result == null
        ? 'Adapt this activity'
        : 'Need to adjust this activity?';

    return Card.outlined(
      color: AppColors.surfaceCanvas,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: AppColors.forest,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(headerTitle, style: theme.textTheme.titleSmall),
                ),
                if (!isExpanded && result == null)
                  OutlinedButton(
                    onPressed: onExpand,
                    child: const Text('Adapt activity'),
                  ),
              ],
            ),
            if (isExpanded && result == null) ...[
              const SizedBox(height: AppSpacing.space12),
              Text(
                'Choose how you would like to adjust this for your child, time, or supplies:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space8,
                children: [
                  for (final option in _adjustmentOptions)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: selectedAdjustment == option.id,
                      onSelected: isAdapting
                          ? null
                          : (_) => onAdjustmentChanged(option.id),
                    ),
                ],
              ),
              if (selectedAdjustment ==
                  ActivityAdjustments.missingMaterial) ...[
                const SizedBox(height: AppSpacing.space12),
                TextField(
                  controller: missingMaterialController,
                  enabled: !isAdapting,
                  decoration: const InputDecoration(
                    labelText: 'What material are you missing?',
                    hintText: 'For example: cups, wooden spoon, towel',
                  ),
                  onChanged: onMissingMaterialChanged,
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.space12),
                InlineErrorCard(
                  message: errorMessage!,
                  onRetry: () {
                    if (!isAdapting) onSubmit();
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.space16),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space8,
                children: [
                  FilledButton(
                    onPressed: isAdapting ? null : onSubmit,
                    child: Text(isAdapting ? 'Adapting…' : 'Adjust activity'),
                  ),
                  TextButton(
                    onPressed: isAdapting ? null : onCollapse,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
            if (result != null)
              AdaptedActivityCard(
                response: result,
                isScheduling: isScheduling,
                onTryAnother: onTryAnother,
                onAddAdapted: onAddAdapted,
              ),
          ],
        ),
      ),
    );
  }
}
