import 'package:flutter/material.dart';

import '../../../models/milestone.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/horizontal_scroll_fade.dart';

/// Tappable age-range selector displayed at the top of the Milestones tab.
class MilestoneAgeBandSelector extends StatelessWidget {
  /// Creates a [MilestoneAgeBandSelector].
  const MilestoneAgeBandSelector({
    super.key,
    required this.selectedAgeBand,
    required this.onTap,
  });

  /// Currently selected milestone age-range label (for example, `12-23 months`).
  final String selectedAgeBand;

  /// Callback invoked when the caregiver taps to pick another age range.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Child's age",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    Text(
                      selectedAgeBand,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet allowing caregivers to browse any milestone age range.
class MilestoneAgeBandPickerSheet extends StatelessWidget {
  /// Creates a [MilestoneAgeBandPickerSheet].
  const MilestoneAgeBandPickerSheet({
    super.key,
    required this.ageBands,
    required this.selectedAgeBand,
    required this.onSelected,
  });

  /// Ordered list of milestone age-range labels.
  final List<String> ageBands;

  /// Currently active age-range label.
  final String selectedAgeBand;

  /// Callback invoked when the caregiver chooses an age range.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Child's age range",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'You can browse any age range.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            ...ageBands.map((band) {
              final isSelected = band == selectedAgeBand;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space8,
                  vertical: AppSpacing.space4,
                ),
                title: Text(
                  band,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.forest
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.forest)
                    : null,
                onTap: () {
                  onSelected(band);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading view displayed while milestone prompts load.
class MilestonesLoadingSkeleton extends StatelessWidget {
  /// Creates a [MilestonesLoadingSkeleton].
  const MilestonesLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loading milestones...',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.space16),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Container(
              height: 72,
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(
                              AppRadius.skeleton,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        Container(
                          width: 140,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.skeleton,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space16),
                  Container(
                    width: AppSizes.touchTarget,
                    height: AppSpacing.space32,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Calm empty-state card displayed before any milestone observations are noted.
class MilestonesEmptyCard extends StatelessWidget {
  /// Creates a [MilestonesEmptyCard].
  const MilestonesEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Center(
        child: Column(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.softGreen,
              radius: 24,
              child: Icon(
                Icons.eco_outlined,
                color: AppColors.forest,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              'Nothing noted yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Look for small moments during play.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of domain filter chips with right-edge scroll fade.
class MilestoneDomainFilters extends StatelessWidget {
  /// Creates a [MilestoneDomainFilters] row.
  const MilestoneDomainFilters({
    super.key,
    required this.selectedDomain,
    required this.onSelected,
  });

  /// Active domain filter, or `null` when "All" is selected.
  final MilestoneDomain? selectedDomain;

  /// Callback invoked when the caregiver selects a domain filter chip.
  final ValueChanged<MilestoneDomain?> onSelected;

  @override
  Widget build(BuildContext context) {
    return HorizontalScrollFade(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: AppSpacing.space20),
        child: Row(
          children: [
            _MilestoneDomainChip(
              label: 'All',
              selected: selectedDomain == null,
              onSelected: () => onSelected(null),
            ),
            ...MilestoneDomain.values.map(
              (domain) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.space8),
                child: _MilestoneDomainChip(
                  label: domain.label,
                  selected: selectedDomain == domain,
                  onSelected: () => onSelected(domain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneDomainChip extends StatelessWidget {
  const _MilestoneDomainChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.forest,
      backgroundColor: AppColors.surfaceCard,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? AppColors.surfaceCard : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: BorderSide(
          color: selected ? AppColors.forest : AppColors.borderSubtle,
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
