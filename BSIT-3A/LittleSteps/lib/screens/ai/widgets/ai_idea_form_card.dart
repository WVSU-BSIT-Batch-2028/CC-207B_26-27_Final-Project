import 'package:flutter/material.dart';

import '../../../models/age_band.dart';
import '../../../models/weather.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';
import '../../../widgets/weather_hint_banner.dart';

/// Play setting choices accepted by the Idea Helper request.
enum PlaySettingOption {
  /// Either indoor or outdoor play.
  either(PlaySetting.either, 'Indoor or outdoor'),

  /// Indoor play only.
  indoor(PlaySetting.indoor, 'Indoor'),

  /// Outdoor play only.
  outdoor(PlaySetting.outdoor, 'Outdoor');

  const PlaySettingOption(this.code, this.label);

  /// API wire value sent to the recommendation endpoint.
  final String code;

  /// Caregiver-facing chip label.
  final String label;
}

/// Supported caregiver languages for Idea Helper recommendations.
enum PlayLanguageOption {
  /// English language responses.
  english(AppLanguages.english, 'English'),

  /// Filipino language responses.
  filipino(AppLanguages.filipino, 'Filipino'),

  /// Hiligaynon language responses.
  hiligaynon(AppLanguages.hiligaynon, 'Hiligaynon');

  const PlayLanguageOption(this.code, this.label);

  /// ISO-639 language code sent to the recommendation endpoint.
  final String code;

  /// Caregiver-facing chip label.
  final String label;
}

/// Form card collecting time, setting, age band, language, and materials.
class AiIdeaFormCard extends StatelessWidget {
  /// Creates an [AiIdeaFormCard].
  const AiIdeaFormCard({
    super.key,
    required this.timeOptions,
    required this.selectedTimeMinutes,
    required this.selectedSetting,
    required this.selectedAgeBand,
    required this.selectedLanguage,
    required this.materialsController,
    required this.onTimeChanged,
    required this.onSettingChanged,
    required this.onAgeBandChanged,
    required this.onLanguageChanged,
    required this.onSubmit,
    this.weatherHint,
    this.weatherCityLabel,
  });

  /// Preset play duration choices in minutes.
  final List<int> timeOptions;

  /// Currently selected play duration in minutes.
  final int selectedTimeMinutes;

  /// Currently selected play setting code (`either`, `indoor`, or `outdoor`).
  final String selectedSetting;

  /// Currently selected child age band wire code (for example, `12-23m`).
  final String selectedAgeBand;

  /// Currently selected language code (`en`, `fil`, or `hil`).
  final String selectedLanguage;

  /// Controller for comma-separated household materials input.
  final TextEditingController materialsController;

  /// Callback invoked when the caregiver selects a duration chip.
  final ValueChanged<int> onTimeChanged;

  /// Callback invoked when the caregiver selects a play setting chip.
  final ValueChanged<String> onSettingChanged;

  /// Callback invoked when the caregiver selects a child age band.
  final ValueChanged<String> onAgeBandChanged;

  /// Callback invoked when the caregiver selects a language chip.
  final ValueChanged<String> onLanguageChanged;

  /// Callback invoked when the caregiver submits the form.
  final VoidCallback onSubmit;

  /// Optional weather guidance banner shown above the form inputs.
  final WeatherHint? weatherHint;

  /// Optional city label paired with [weatherHint] attribution.
  final String? weatherCityLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = weatherHint;
    final sectionLabelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Idea helper',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Find a play idea with the time and materials you have.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            if (hint != null && !hint.isUnavailable) ...[
              WeatherHintBanner(
                hint: hint,
                cityLabel: weatherCityLabel,
                advisoryTone: true,
              ),
              const SizedBox(height: AppSpacing.space16),
            ],
            Text('How much time do you have?', style: sectionLabelStyle),
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              children: timeOptions.map((mins) {
                return ChoiceChip(
                  label: Text('$mins min'),
                  selected: selectedTimeMinutes == mins,
                  onSelected: (selected) {
                    if (selected) onTimeChanged(mins);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('Where will you play?', style: sectionLabelStyle),
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              children: PlaySettingOption.values.map((opt) {
                return ChoiceChip(
                  label: Text(opt.label),
                  selected: selectedSetting == opt.code,
                  onSelected: (selected) {
                    if (selected) onSettingChanged(opt.code);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('Child age range', style: sectionLabelStyle),
            const SizedBox(height: AppSpacing.space8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedAgeBand,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space8,
                ),
              ),
              items: ageBands.map((band) {
                return DropdownMenuItem<String>(
                  value: band.code,
                  child: Text(band.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onAgeBandChanged(val);
              },
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('Language', style: sectionLabelStyle),
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              children: PlayLanguageOption.values.map((opt) {
                return ChoiceChip(
                  label: Text(opt.label),
                  selected: selectedLanguage == opt.code,
                  onSelected: (selected) {
                    if (selected) onLanguageChanged(opt.code);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('What do you have at home?', style: sectionLabelStyle),
            const SizedBox(height: AppSpacing.space4),
            TextFormField(
              controller: materialsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'For example: cups, spoon, towel, paper',
                helperText: 'Materials only, no names. Comma-separated.',
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCanvas,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      'We send only: time, setting, materials, and age band. '
                      'Child names and notes are never sent.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            SizedBox(
              width: double.infinity,
              height: AppSizes.touchTarget,
              child: FilledButton(
                onPressed: onSubmit,
                child: const Text('Find play ideas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
