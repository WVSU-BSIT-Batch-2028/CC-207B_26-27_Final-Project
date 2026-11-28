import 'package:flutter/material.dart';

import '../config/external_links.dart';
import '../models/weather.dart';
import '../theme/app_tokens.dart';
import '../utils/domain_labels.dart';
import '../utils/url_helper.dart';

/// Weather guidance banner with Open-Meteo attribution and optional play-idea
/// call to action.
///
/// Renders standardized indoor, outdoor, or general play guidance derived from
/// [hint]. Supports an optional dismiss button ([onDismiss]), city attribution
/// ([cityLabel]), and a unified [onFindIdeas] action passing the recommended
/// play setting (`indoor`, `outdoor`, or `either`).
class WeatherHintBanner extends StatelessWidget {
  /// Creates a [WeatherHintBanner].
  const WeatherHintBanner({
    super.key,
    required this.hint,
    this.cityLabel,
    this.onDismiss,
    this.onFindIdeas,
    this.advisoryTone = false,
    this.margin,
  });

  /// Weather hint returned by the backend weather service.
  final WeatherHint hint;

  /// Optional city name prefixed before the Open-Meteo attribution.
  final String? cityLabel;

  /// Optional callback invoked when the caregiver dismisses the banner.
  final VoidCallback? onDismiss;

  /// Optional callback invoked with the normalized play setting (`indoor`,
  /// `outdoor`, or `either`) when the caregiver taps the play-idea action button.
  final ValueChanged<String>? onFindIdeas;

  /// Whether to use the warm advisory surface instead of soft green.
  final bool advisoryTone;

  /// Optional outer margin around the banner container.
  final EdgeInsetsGeometry? margin;

  IconData _weatherIcon() {
    if (hint.isRainy) return Icons.cloud_outlined;
    if (hint.heatFlag) return Icons.thermostat_outlined;
    return Icons.wb_sunny_outlined;
  }

  bool get _hasAction => onFindIdeas != null;

  String get _resolvedSetting {
    if (hint.isIndoorSuggested) return PlaySetting.indoor;
    if (hint.isOutdoorSuggested) return PlaySetting.outdoor;
    return PlaySetting.either;
  }

  String _actionLabel() {
    if (hint.isIndoorSuggested || hint.isOutdoorSuggested) {
      final settingWord = formatSettingLabel(_resolvedSetting).toLowerCase();
      return 'Find $settingWord ideas';
    }
    return 'Find play ideas';
  }

  @override
  Widget build(BuildContext context) {
    if (hint.isUnavailable) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final showAction = _hasAction;
    final displayHint = hint.displayMessage(stripActionSuffix: showAction);
    final attributionText = cityLabel != null && cityLabel!.isNotEmpty
        ? '$cityLabel · ${hint.attribution}'
        : hint.attribution;

    return Semantics(
      liveRegion: true,
      label: 'Weather guidance: $displayHint',
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: advisoryTone ? AppColors.surfaceAdvisory : AppColors.softGreen,
          borderRadius: BorderRadius.circular(
            advisoryTone ? AppRadius.chip : AppRadius.card,
          ),
          border: Border.all(
            color: advisoryTone
                ? AppColors.borderAdvisory
                : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _weatherIcon(),
                  size: 18,
                  color: advisoryTone
                      ? AppColors.textPrimary
                      : AppColors.forest,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    displayHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dismiss weather hint',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppSizes.touchTarget,
                      minHeight: AppSizes.touchTarget,
                    ),
                    onPressed: onDismiss,
                  ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.space12,
              runSpacing: AppSpacing.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  link: true,
                  hint: 'Opens external website',
                  child: InkWell(
                    onTap: () => openExternalUrl(context, AppLinks.openMeteo),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            attributionText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space4),
                          const Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showAction)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space8,
                      ),
                      minimumSize: const Size(0, AppSizes.touchTarget),
                    ),
                    onPressed: () => onFindIdeas!(_resolvedSetting),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(_actionLabel()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
