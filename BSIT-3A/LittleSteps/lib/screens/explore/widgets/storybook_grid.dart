import 'package:flutter/material.dart';

import '../../../models/book.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/book_card.dart';

/// Responsive grid of picture books with incremental load-more pagination.
class StorybookGrid extends StatelessWidget {
  /// Creates a [StorybookGrid].
  const StorybookGrid({
    super.key,
    required this.books,
    required this.visibleCount,
    required this.isBookSaved,
    required this.pendingSaveIds,
    required this.onToggleSave,
    required this.onGetPlayIdea,
    required this.onLoadMore,
  });

  /// Full list of books available for the active shelf or search query.
  final List<BookItem> books;

  /// Maximum number of items currently rendered before "Load more books".
  final int visibleCount;

  /// Predicate returning whether a book ID is saved on the child's bookshelf.
  final bool Function(String bookId) isBookSaved;

  /// Set of book IDs currently undergoing a save or remove request.
  final Set<String> pendingSaveIds;

  /// Callback invoked when the caregiver saves or removes a book.
  final ValueChanged<BookItem> onToggleSave;

  /// Callback invoked when the caregiver opens the AI Play Companion dialog.
  final ValueChanged<BookItem> onGetPlayIdea;

  /// Callback invoked when the caregiver taps "Load more books".
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final visibleBooks = books.take(visibleCount).toList();
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: AppSizes.bookGridMaxTileExtent,
            crossAxisSpacing: AppSpacing.space12,
            mainAxisSpacing: AppSpacing.space16,
            mainAxisExtent: 280 + MediaQuery.textScalerOf(context).scale(70),
          ),
          itemCount: visibleBooks.length,
          itemBuilder: (context, index) {
            final book = visibleBooks[index];
            return BookCard(
              book: book,
              isSaved: isBookSaved(book.id),
              isSaving: pendingSaveIds.contains(book.id),
              onToggleSave: () => onToggleSave(book),
              onGetPlayIdea: () => onGetPlayIdea(book),
            );
          },
        ),
        if (books.length > visibleCount) ...[
          const SizedBox(height: AppSpacing.space16),
          Text(
            'Showing ${visibleBooks.length} of ${books.length} books',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.space8),
          OutlinedButton(
            onPressed: onLoadMore,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              foregroundColor: AppColors.forest,
            ),
            child: const Text('Load more books'),
          ),
        ],
      ],
    );
  }
}
