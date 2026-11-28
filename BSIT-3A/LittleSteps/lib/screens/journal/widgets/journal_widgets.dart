import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/journal_entry.dart';
import '../../../theme/app_tokens.dart';

/// Opens a clamped date picker covering the last six years up to today.
Future<DateTime?> pickJournalDate(
  BuildContext context, {
  required DateTime initialDate,
  required String helpText,
}) {
  final now = DateTime.now();
  final firstDate = DateTime(now.year - 6);
  var clamped = initialDate;
  if (clamped.isBefore(firstDate)) {
    clamped = firstDate;
  } else if (clamped.isAfter(now)) {
    clamped = now;
  }
  return showDatePicker(
    context: context,
    initialDate: clamped,
    firstDate: firstDate,
    lastDate: now,
    helpText: helpText,
  );
}

/// Card summarizing a single private caregiver journal note.
class JournalEntryCard extends StatelessWidget {
  /// Creates a [JournalEntryCard].
  const JournalEntryCard({super.key, required this.entry, required this.onTap});

  /// Private journal entry displayed by this card.
  final JournalEntry entry;

  /// Callback invoked when the caregiver taps the card to view or edit it.
  final VoidCallback onTap;

  String get _formattedDate {
    final date = DateTime.tryParse(entry.entryDate);
    return date == null ? entry.entryDate : DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formattedDate,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const JournalPrivateBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                entry.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact pill badge marking caregiver journal records as private.
class JournalPrivateBadge extends StatelessWidget {
  /// Creates a [JournalPrivateBadge].
  const JournalPrivateBadge({super.key, this.filled = true});

  /// Whether to render the soft-green pill container behind the lock label.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline,
          size: filled ? 14 : 16,
          color: AppColors.forest,
        ),
        const SizedBox(width: AppSpacing.space4),
        Text(
          'Private',
          style:
              (filled
                      ? Theme.of(context).textTheme.labelSmall
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.bold,
                  ),
        ),
      ],
    );

    if (!filled) return row;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: row,
    );
  }
}

/// Privacy boundary notice displayed above private journal note inputs.
class JournalPrivacyNotice extends StatelessWidget {
  /// Creates a [JournalPrivacyNotice].
  const JournalPrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.forest),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private to you',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  'Only you can see this note. It is never shared, '
                  'used for AI ideas, or shown to anyone else.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
