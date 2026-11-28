import 'package:flutter/material.dart';

import '../../../models/rhyme.dart';
import '../../../theme/app_tokens.dart';

/// List of traditional Philippine nursery rhymes and interactive action games.
class RhymesShelf extends StatelessWidget {
  /// Creates a [RhymesShelf].
  const RhymesShelf({
    super.key,
    required this.rhymes,
    required this.childNickname,
    required this.onShowDetails,
    required this.onScheduleRhyme,
  });

  /// Rhymes fetched from the catalog API and rendered on the shelf.
  final List<PhilippineRhyme> rhymes;

  /// Active child's nickname (or fallback phrase) shown in the shelf subtitle.
  final String childNickname;

  /// Callback invoked when the caregiver opens the full lyrics sheet.
  final ValueChanged<PhilippineRhyme> onShowDetails;

  /// Callback invoked when the caregiver adds a rhyme to today's plan.
  final ValueChanged<PhilippineRhyme> onScheduleRhyme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space12),
          child: Text(
            'Traditional songs and rhythm games with $childNickname',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...rhymes.map(
          (rhyme) => _RhymeCard(
            rhyme: rhyme,
            onShowDetails: () => onShowDetails(rhyme),
            onScheduleRhyme: () => onScheduleRhyme(rhyme),
          ),
        ),
      ],
    );
  }
}

class _RhymeCard extends StatelessWidget {
  const _RhymeCard({
    required this.rhyme,
    required this.onShowDetails,
    required this.onScheduleRhyme,
  });

  final PhilippineRhyme rhyme;
  final VoidCallback onShowDetails;
  final VoidCallback onScheduleRhyme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space16),
      decoration: ShapeDecoration(
        color: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onShowDetails,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space8,
                        vertical: AppSpacing.space4 / 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Text(
                        rhyme.domainLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Text(
                      '${rhyme.durationMinutes} mins',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  rhyme.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  rhyme.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.normal,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCanvas,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lyrics snippet:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        rhyme.lyrics.take(4).join('\n'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.normal,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                Text(
                  'How to play: ${rhyme.actionPrompt}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                OutlinedButton(
                  onPressed: onScheduleRhyme,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    minimumSize: const Size.fromHeight(
                      AppSizes.touchTargetSecondary,
                    ),
                  ),
                  child: const Text("Add to today's plan"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
