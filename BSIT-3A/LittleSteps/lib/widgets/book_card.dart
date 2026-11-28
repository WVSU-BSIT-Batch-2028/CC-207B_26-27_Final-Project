import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_tokens.dart';

/// Storybook card displaying cover art, metadata, bookmark toggle, and play
/// idea action.
class BookCard extends StatelessWidget {
  /// Creates a [BookCard].
  const BookCard({
    super.key,
    required this.book,
    this.isSaved = false,
    this.onToggleSave,
    this.onGetPlayIdea,
    this.isSaving = false,
  });

  /// Book metadata rendered by this card.
  final BookItem book;

  /// Whether [book] is currently saved to the family bookshelf.
  final bool isSaved;

  /// Callback invoked when the caregiver toggles the bookshelf bookmark.
  final VoidCallback? onToggleSave;

  /// Callback invoked when the caregiver requests a companion play idea.
  final VoidCallback? onGetPlayIdea;

  /// Whether a bookmark save or remove request is currently in progress.
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authorText = book.authors.isNotEmpty
        ? book.authors.join(', ')
        : 'Unknown author';
    final subjectsText = book.subjects.isNotEmpty
        ? book.subjects.take(2).join(' · ')
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.card - 1),
                ),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: AppColors.softGreen,
                  child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                      ? Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildFallbackCover(theme);
                          },
                        )
                      : _buildFallbackCover(theme),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Semantics(
                  container: true,
                  button: true,
                  selected: isSaved,
                  label: isSaved
                      ? 'Remove "${book.title}" from bookshelf'
                      : 'Save "${book.title}" to bookshelf',
                  child: Material(
                    color: AppColors.surfaceCard.withAlpha(230),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isSaving ? null : onToggleSave,
                      child: Container(
                        width: AppSizes.touchTarget,
                        height: AppSizes.touchTarget,
                        alignment: Alignment.center,
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.forest,
                                ),
                              )
                            : Icon(
                                isSaved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border_outlined,
                                color: isSaved
                                    ? AppColors.forest
                                    : AppColors.textPrimary,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    authorText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (subjectsText != null) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      subjectsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  const SizedBox(height: AppSpacing.space4),
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.touchTarget,
                    child: OutlinedButton(
                      onPressed: onGetPlayIdea,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        side: const BorderSide(color: AppColors.borderInput),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space8,
                        ),
                      ),
                      child: Text(
                        'Get a play idea',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(ThemeData theme) {
    return Container(
      color: AppColors.softGreen,
      padding: const EdgeInsets.all(AppSpacing.space16),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, color: AppColors.forest, size: 36),
          const SizedBox(height: AppSpacing.space8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
