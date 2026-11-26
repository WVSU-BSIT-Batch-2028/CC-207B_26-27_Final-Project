// A row of chips that scrolls sideways, for filtering a list by crop
// (website .chips). The selected chip turns green.

import 'package:flutter/material.dart';

import '../utils/crop_catalog.dart';
import '../utils/theme.dart';

/// One chip per option, plus an "All" chip first when [allLabel] is given.
/// [selected] is null when "All" is picked.
class ChipFilterRow extends StatelessWidget {
  const ChipFilterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allLabel = 'All crops',
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final option in [null, ...options])
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.small),
              child: ChoiceChip(
                label: Text(option ?? allLabel),
                selected: selected == option,
                showCheckmark: false,
                onSelected: (_) => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chips for the 6 crop categories plus "All crops", so 71 crops never
/// become a wall of chips. Use it next to a crop dropdown that only lists
/// the crops of the chosen category.
class CategoryChipRow extends StatelessWidget {
  const CategoryChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CropCategory? selected; // null = all
  final ValueChanged<CropCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final category in [null, ...CropCategory.values])
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.small),
              child: ChoiceChip(
                avatar: category == null
                    ? null
                    : Icon(
                        category.icon,
                        size: 16,
                        color: selected == category
                            ? Colors.white
                            : AppColors.link,
                      ),
                label: Text(category?.label ?? 'All crops'),
                selected: selected == category,
                showCheckmark: false,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}
