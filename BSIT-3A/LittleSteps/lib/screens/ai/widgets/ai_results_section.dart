import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/domain_labels.dart';
import 'ai_play_block_banner.dart';
import 'ai_suggestion_card.dart';

/// Displays Idea Helper results, provenance labels, notices, and recovery CTAs.
class AiResultsSection extends StatelessWidget {
  /// Creates an [AiResultsSection].
  const AiResultsSection({
    super.key,
    required this.response,
    required this.timeMinutes,
    required this.hasActiveChild,
    required this.isAddingAll,
    required this.isAlreadyAdded,
    required this.onAddToPlan,
    required this.onAddAll,
    required this.onRetry,
    required this.onEditPreferences,
    required this.onBackToActivities,
    this.rateLimitMessage,
    this.fallbackNotice,
  });

  /// Recommendation payload returned by the AI or fallback catalog service.
  final RecommendationResponse response;

  /// Requested play window in minutes.
  final int timeMinutes;

  /// Whether an active child profile is selected for adding to today's plan.
  final bool hasActiveChild;

  /// Whether a batch add-to-plan operation is currently running.
  final bool isAddingAll;

  /// Returns whether a recommendation has already been added to today's plan.
  final bool Function(Recommendation item) isAlreadyAdded;

  /// Callback invoked when adding a single recommendation to today's plan.
  final ValueChanged<Recommendation> onAddToPlan;

  /// Callback invoked when adding all Play Block suggestions to today's plan.
  final VoidCallback onAddAll;

  /// Callback invoked when requesting another set of recommendations.
  final VoidCallback onRetry;

  /// Callback invoked when returning to the Idea Helper input form.
  final VoidCallback onEditPreferences;

  /// Callback invoked from the rate-limit notice to return to activities.
  final VoidCallback onBackToActivities;

  /// Optional message displayed when hourly AI request limits are reached.
  final String? rateLimitMessage;

  /// Optional notice displayed when catalog fallback picks are shown.
  final String? fallbackNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAi = response.isAiGenerated;
    final suggestions = response.suggestions;
    final allAdded =
        suggestions.isNotEmpty && suggestions.every(isAlreadyAdded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rateLimitMessage != null) ...[
          _AiAdvisoryCard(
            icon: Icons.timer_outlined,
            title: 'Taking a short break',
            body: rateLimitMessage!,
            action: OutlinedButton.icon(
              onPressed: onBackToActivities,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to activities'),
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
        ],
        if (fallbackNotice != null && rateLimitMessage == null) ...[
          _AiAdvisoryCard(
            icon: Icons.info_outline,
            title: 'Using our activity list',
            body: fallbackNotice!,
          ),
          const SizedBox(height: AppSpacing.space16),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.space8,
          runSpacing: AppSpacing.space8,
          children: [
            Text(
              isAi ? 'AI suggestions' : 'Catalog picks · not AI',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isAi) const _AiProvenanceBadge(),
          ],
        ),
        if (isAi) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            response.isCustomGenerated
                ? 'Custom idea tailored to your materials; not from the reviewed catalog.'
                : 'Matched from reviewed LittleSteps activities for your inputs.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (response.materialNote != null &&
            response.materialNote!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space12),
          _AiAdvisoryCard(
            icon: Icons.health_and_safety_outlined,
            body: response.materialNote!,
            compact: true,
          ),
        ],
        const SizedBox(height: AppSpacing.space8),
        if (timeMinutes >= 30 && suggestions.isNotEmpty) ...[
          AiPlayBlockBanner(
            suggestions: suggestions,
            timeMinutes: timeMinutes,
            hasActiveChild: hasActiveChild,
            allAdded: allAdded,
            isAddingAll: isAddingAll,
            onAddAll: onAddAll,
          ),
          const SizedBox(height: AppSpacing.space12),
        ],
        _AiDisclaimerBox(isAi: isAi, disclaimer: response.disclaimer),
        const SizedBox(height: AppSpacing.space16),
        if (suggestions.isEmpty)
          const _AiEmptyRecoveryCard()
        else
          ...suggestions.map((suggestion) {
            return AiSuggestionCard(
              suggestion: suggestion,
              settingLabel: formatSettingLabel(
                suggestion.activity?.setting ?? '',
              ),
              hasActiveChild: hasActiveChild,
              alreadyAdded: isAlreadyAdded(suggestion),
              onAddToPlan: () => onAddToPlan(suggestion),
            );
          }),
        const SizedBox(height: AppSpacing.space16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onRetry,
                child: Text(isAi ? 'Generate another' : 'Try again'),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: TextButton(
                onPressed: onEditPreferences,
                child: const Text('Edit preferences'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space24),
      ],
    );
  }
}

class _AiAdvisoryCard extends StatelessWidget {
  const _AiAdvisoryCard({
    required this.icon,
    required this.body,
    this.title,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String body;
  final String? title;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(
        compact ? AppSpacing.space12 : AppSpacing.space16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAdvisory,
        borderRadius: BorderRadius.circular(
          compact ? AppRadius.chip : AppRadius.card,
        ),
        border: Border.all(color: AppColors.borderAdvisory),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 18 : 20, color: AppColors.textPrimary),
          SizedBox(width: compact ? AppSpacing.space8 : AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.space12),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiProvenanceBadge extends StatelessWidget {
  const _AiProvenanceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.forest),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: AppColors.forest),
          const SizedBox(width: AppSpacing.space4),
          Text(
            'Suggested by AI',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiDisclaimerBox extends StatelessWidget {
  const _AiDisclaimerBox({required this.isAi, required this.disclaimer});

  final bool isAi;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAi
                ? 'Suggested by AI: always adapt activities to your child and ensure adult supervision.'
                : 'Always adapt activities to your child and ensure adult supervision.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            disclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiEmptyRecoveryCard extends StatelessWidget {
  const _AiEmptyRecoveryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 36,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              'No matching play ideas yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Try changing the time, setting, or language, or tap Try again once your connection is ready.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
