import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/horizontal_scroll_fade.dart';
import '../storybooks_section.dart';

export '../../../widgets/horizontal_scroll_fade.dart';

/// Horizontal section switcher across Activities, Storybooks, Bookshelf, and Rhymes.
class ExploreSectionTabs extends StatelessWidget {
  /// Creates an [ExploreSectionTabs].
  const ExploreSectionTabs({
    super.key,
    required this.storybooksSelected,
    required this.selectedShelf,
    required this.savedBookCount,
    required this.onActivities,
    required this.onStorybooks,
    required this.onBookshelf,
    required this.onRhymes,
  });

  /// Whether one of the storybook/rhyme shelves is currently active.
  final bool storybooksSelected;

  /// Active shelf when [storybooksSelected] is `true`.
  final BookshelfShelf selectedShelf;

  /// Number of books saved on the active child's bookshelf.
  final int savedBookCount;

  /// Callback selecting the Activities catalog view.
  final VoidCallback onActivities;

  /// Callback selecting the Open Library Storybooks shelf.
  final VoidCallback onStorybooks;

  /// Callback selecting the child's saved Bookshelf.
  final VoidCallback onBookshelf;

  /// Callback selecting the Read & Sing Together rhymes shelf.
  final VoidCallback onRhymes;

  @override
  Widget build(BuildContext context) => HorizontalScrollFade(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(right: AppSpacing.space24),
      child: Row(
        children: [
          _SectionButton(
            label: const Text('Activities'),
            selected: !storybooksSelected,
            onPressed: onActivities,
          ),
          const SizedBox(width: AppSpacing.space8),
          _SectionButton(
            label: const Text('Storybooks'),
            selected:
                storybooksSelected &&
                selectedShelf == BookshelfShelf.openLibrary,
            onPressed: onStorybooks,
          ),
          const SizedBox(width: AppSpacing.space8),
          _SectionButton(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Our Bookshelf'),
                if (savedBookCount > 0) ...[
                  const SizedBox(width: AppSpacing.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          storybooksSelected &&
                              selectedShelf == BookshelfShelf.ourBookshelf
                          ? AppColors.surfaceCard
                          : AppColors.softGreen,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      '$savedBookCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selected:
                storybooksSelected &&
                selectedShelf == BookshelfShelf.ourBookshelf,
            onPressed: onBookshelf,
          ),
          const SizedBox(width: AppSpacing.space8),
          _SectionButton(
            label: const Text('Read & Sing Together'),
            selected:
                storybooksSelected && selectedShelf == BookshelfShelf.rhymes,
            onPressed: onRhymes,
          ),
        ],
      ),
    ),
  );
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppSizes.touchTarget,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
              ),
              child: label,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: label,
            ),
    );
  }
}

/// Search field paired with the badged advanced-filters button for Explore.
class ExploreSearchFilterRow extends StatelessWidget {
  /// Creates an [ExploreSearchFilterRow].
  const ExploreSearchFilterRow({
    super.key,
    required this.controller,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onOpenFilters,
  });

  /// Text controller backing the catalog search input.
  final TextEditingController controller;

  /// Number of non-default filters currently active in the filter sheet.
  final int activeFilterCount;

  /// Callback invoked whenever the search query changes.
  final ValueChanged<String> onSearchChanged;

  /// Callback invoked when the caregiver taps the filter button.
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('materials-search'),
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search activities or materials',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: OutlinedButton(
            key: const ValueKey('more-filters'),
            onPressed: onOpenFilters,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              side: BorderSide(
                color: activeFilterCount > 0
                    ? AppColors.forest
                    : AppColors.borderInput,
              ),
              backgroundColor: activeFilterCount > 0
                  ? AppColors.softGreen
                  : AppColors.surfaceCard,
            ),
            child: Tooltip(
              message: activeFilterCount > 0
                  ? 'Filters ($activeFilterCount active)'
                  : 'Filters',
              child: Badge.count(
                count: activeFilterCount,
                isLabelVisible: activeFilterCount > 0,
                backgroundColor: AppColors.forest,
                child: const Icon(Icons.tune, color: AppColors.forest),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal row of developmental domain filter chips for Explore.
class ExploreDomainFilters extends StatelessWidget {
  /// Creates an [ExploreDomainFilters].
  const ExploreDomainFilters({
    super.key,
    required this.domains,
    required this.selectedDomain,
    required this.onSelected,
    this.horizontalPadding = AppSpacing.space16,
  });

  /// Map of API domain keys to caregiver-friendly display labels.
  final Map<String, String> domains;

  /// Currently selected domain key, or `null` when "All" is active.
  final String? selectedDomain;

  /// Callback invoked when the caregiver selects a domain filter chip.
  final ValueChanged<String?> onSelected;

  /// Horizontal inset padding matching the surrounding layout column.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String?)>[
      ('All', null),
      ...domains.entries.map((entry) => (entry.value, entry.key)),
    ];
    return SizedBox(
      height: AppSizes.touchTarget,
      child: HorizontalScrollFade(
        child: ListView.separated(
          key: const ValueKey('domain-filters'),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding + AppSpacing.space20,
            0,
          ),
          itemCount: filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.space8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final selected = selectedDomain == filter.$2;
            return SizedBox(
              height: AppSizes.touchTarget,
              child: ChoiceChip(
                key: ValueKey('domain-${filter.$2 ?? 'all'}'),
                label: Text(filter.$1),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(filter.$2),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Choice chip selecting a catalog language or setting filter value.
class LanguageFilterChip extends StatelessWidget {
  /// Creates a [LanguageFilterChip].
  const LanguageFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  /// Filter option label.
  final String label;

  /// Whether this option is currently active.
  final bool selected;

  /// Callback invoked when the chip is tapped.
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onSelected(),
  );
}

/// Compact inline entry card inviting caregivers to launch the AI Idea Helper.
class CompactIdeaHelperBar extends StatelessWidget {
  /// Creates a [CompactIdeaHelperBar].
  const CompactIdeaHelperBar({super.key, required this.onTap});

  /// Callback invoked when the caregiver opens the AI Idea Helper.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      color: AppColors.softGreen.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.forest,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need a play idea?',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Match time and items at home.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12,
                  ),
                ),
                child: const Text('Get a play idea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
