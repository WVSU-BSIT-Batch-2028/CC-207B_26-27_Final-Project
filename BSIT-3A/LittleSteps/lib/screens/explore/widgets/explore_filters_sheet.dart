import 'package:flutter/material.dart';

import '../../../models/age_band.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';
import 'explore_filter_controls.dart';

/// Modal bottom sheet allowing caregivers to refine Explore age, language,
/// and play-space filters.
class ExploreFiltersSheet extends StatefulWidget {
  /// Creates an [ExploreFiltersSheet].
  const ExploreFiltersSheet({
    super.key,
    required this.initialAgeBand,
    required this.defaultAgeBand,
    required this.selectedLanguage,
    required this.selectedSetting,
    required this.onAgeBandChanged,
    required this.onLanguageSelected,
    required this.onSettingSelected,
    required this.onResetFilters,
  });

  /// Currently selected catalog age-band code, or `null` for all ages.
  final String? initialAgeBand;

  /// Default age-band code derived from the active child profile.
  final String? defaultAgeBand;

  /// Currently selected ISO-639 language code, or `null` for all languages.
  final String? selectedLanguage;

  /// Currently selected play setting code, or `null` for any play space.
  final String? selectedSetting;

  /// Callback invoked when the caregiver changes the age-band dropdown.
  final ValueChanged<String?> onAgeBandChanged;

  /// Callback invoked when the caregiver selects a language chip.
  final ValueChanged<String?> onLanguageSelected;

  /// Callback invoked when the caregiver selects a play-space chip.
  final ValueChanged<String?> onSettingSelected;

  /// Callback invoked when the caregiver resets all sheet filters to defaults.
  final VoidCallback onResetFilters;

  @override
  State<ExploreFiltersSheet> createState() => _ExploreFiltersSheetState();
}

class _ExploreFiltersSheetState extends State<ExploreFiltersSheet> {
  late String? _ageBand;

  @override
  void initState() {
    super.initState();
    _ageBand = widget.initialAgeBand;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomFilters =
        _ageBand != widget.defaultAgeBand ||
        widget.selectedLanguage != null ||
        widget.selectedSetting != null;

    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: theme.textTheme.titleLarge),
                  if (hasCustomFilters)
                    TextButton(
                      onPressed: () {
                        widget.onResetFilters();
                        Navigator.pop(context);
                      },
                      child: const Text('Reset filters'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              Text("Child's age", style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.space8),
              DropdownButtonFormField<String?>(
                key: ValueKey('age-$_ageBand'),
                initialValue: _ageBand,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Child's age"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All age bands'),
                  ),
                  ...ageBands.map(
                    (band) => DropdownMenuItem<String?>(
                      value: band.code,
                      child: Text(band.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _ageBand = value);
                  widget.onAgeBandChanged(value);
                },
              ),
              const SizedBox(height: AppSpacing.space20),
              Text('Language', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space8,
                children: [
                  LanguageFilterChip(
                    label: 'All languages',
                    selected: widget.selectedLanguage == null,
                    onSelected: () {
                      widget.onLanguageSelected(null);
                      Navigator.pop(context);
                    },
                  ),
                  ...AppLanguages.labels.entries.map(
                    (entry) => LanguageFilterChip(
                      label: entry.value,
                      selected: widget.selectedLanguage == entry.key,
                      onSelected: () {
                        widget.onLanguageSelected(entry.key);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space20),
              Text('Play space', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space8,
                children: [
                  LanguageFilterChip(
                    label: 'Any space',
                    selected: widget.selectedSetting == null,
                    onSelected: () {
                      widget.onSettingSelected(null);
                      Navigator.pop(context);
                    },
                  ),
                  ...PlaySetting.filterLabels.entries.map(
                    (entry) => LanguageFilterChip(
                      label: entry.value,
                      selected: widget.selectedSetting == entry.key,
                      onSelected: () {
                        widget.onSettingSelected(entry.key);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              Text(
                'Defaults to your active child\'s age range. Adjust anytime to browse other ages or languages.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
