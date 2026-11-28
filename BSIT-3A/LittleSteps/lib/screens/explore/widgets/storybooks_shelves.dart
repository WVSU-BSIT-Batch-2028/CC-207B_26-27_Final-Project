import 'package:flutter/material.dart';

import '../../../models/book.dart';
import '../../../models/rhyme.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/horizontal_scroll_fade.dart';
import '../../../widgets/state_views.dart';
import 'storybook_grid.dart';

/// Subject filter option shown on [OpenLibraryShelf].
@immutable
class StorybookSubjectOption {
  /// Creates a [StorybookSubjectOption].
  const StorybookSubjectOption({required this.id, required this.label});

  /// Open Library subject query parameter.
  final String id;

  /// Caregiver-facing filter chip label.
  final String label;
}

/// Curated children's book subject chips displayed on [OpenLibraryShelf].
const List<StorybookSubjectOption> storybookSubjectOptions = [
  StorybookSubjectOption(id: 'picture_books', label: 'Picture books'),
  StorybookSubjectOption(id: 'animals', label: 'Animals'),
  StorybookSubjectOption(id: 'bedtime', label: 'Bedtime'),
  StorybookSubjectOption(id: 'colors', label: 'Colors'),
];

/// Searchable Open Library storybook catalog shelf.
class OpenLibraryShelf extends StatelessWidget {
  /// Creates an [OpenLibraryShelf].
  const OpenLibraryShelf({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedSubject,
    required this.isLoading,
    required this.showingOfflineNotice,
    required this.errorMessage,
    required this.books,
    required this.visibleCount,
    required this.isBookSaved,
    required this.pendingSaveIds,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSubjectSelected,
    required this.onRetry,
    required this.onShowPictureBooks,
    required this.onToggleSave,
    required this.onGetPlayIdea,
    required this.onLoadMore,
  });

  /// Controller for the Open Library search input.
  final TextEditingController searchController;

  /// Current raw search text.
  final String searchQuery;

  /// Currently active subject filter ID, or `null` for all books.
  final String? selectedSubject;

  /// Whether books are currently being fetched.
  final bool isLoading;

  /// Whether cached/fallback books are displayed while offline.
  final bool showingOfflineNotice;

  /// Error message shown when loading fails with no cached books.
  final String? errorMessage;

  /// Loaded catalog books for the current search or subject filter.
  final List<BookItem> books;

  /// Number of books currently revealed before "Load more books".
  final int visibleCount;

  /// Predicate returning whether a book ID is saved on the family bookshelf.
  final bool Function(String bookId) isBookSaved;

  /// Book IDs currently undergoing a save or remove request.
  final Set<String> pendingSaveIds;

  /// Callback invoked whenever the search query text changes.
  final ValueChanged<String> onSearchChanged;

  /// Callback invoked when the caregiver clears the search field.
  final VoidCallback onClearSearch;

  /// Callback invoked when a subject filter chip is selected or toggled off.
  final ValueChanged<String?> onSubjectSelected;

  /// Callback invoked when the caregiver retries after an error.
  final VoidCallback onRetry;

  /// Callback invoked from the empty state to load picture books.
  final VoidCallback onShowPictureBooks;

  /// Callback invoked when the caregiver saves or removes a book.
  final ValueChanged<BookItem> onToggleSave;

  /// Callback invoked when the caregiver opens the Play Companion dialog.
  final ValueChanged<BookItem> onGetPlayIdea;

  /// Callback invoked when the caregiver taps "Load more books".
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectSummary = searchQuery.isNotEmpty
        ? 'results for "$searchQuery"'
        : (selectedSubject?.replaceAll('_', ' ') ?? 'books');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search books by title or topic',
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClearSearch,
                  )
                : null,
          ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.space12),
        if (searchQuery.isEmpty) ...[
          HorizontalScrollFade(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(right: AppSpacing.space24),
              child: Row(
                children: [
                  _SubjectChip(
                    label: 'All books',
                    selected: selectedSubject == null,
                    onSelected: (_) => onSubjectSelected(null),
                  ),
                  ...storybookSubjectOptions.map(
                    (subject) => _SubjectChip(
                      label: subject.label,
                      selected: selectedSubject == subject.id,
                      onSelected: (selected) =>
                          onSubjectSelected(selected ? subject.id : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
        ],
        if (showingOfflineNotice)
          const _ShelfOfflineNotice(
            message:
                'Open Library is unavailable. Showing a few suggested books.',
          ),
        if (!isLoading && books.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Text(
              '${books.length} $subjectSummary',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (isLoading)
          const _ShelfLoadingSpinner()
        else if (errorMessage != null && books.isEmpty)
          ErrorView(message: errorMessage!, onRetry: onRetry)
        else if (books.isEmpty)
          EmptyStateView(
            title: 'No books found for this topic.',
            message: 'Try another topic, like animals or bedtime.',
            icon: Icons.menu_book_outlined,
            actionLabel: 'Show picture books',
            onAction: onShowPictureBooks,
          )
        else
          StorybookGrid(
            books: books,
            visibleCount: visibleCount,
            isBookSaved: isBookSaved,
            pendingSaveIds: pendingSaveIds,
            onToggleSave: onToggleSave,
            onGetPlayIdea: onGetPlayIdea,
            onLoadMore: onLoadMore,
          ),
      ],
    );
  }
}

/// Family bookshelf displaying books saved for the active child.
class SavedBookshelfView extends StatelessWidget {
  /// Creates a [SavedBookshelfView].
  const SavedBookshelfView({
    super.key,
    required this.hasActiveChild,
    required this.isLoading,
    required this.showingOfflineNotice,
    required this.errorMessage,
    required this.savedBooks,
    required this.visibleCount,
    required this.isBookSaved,
    required this.pendingSaveIds,
    required this.onRetry,
    required this.onSearchBooks,
    required this.onToggleSave,
    required this.onGetPlayIdea,
    required this.onLoadMore,
  });

  /// Whether a child profile is currently selected.
  final bool hasActiveChild;

  /// Whether saved books are currently loading.
  final bool isLoading;

  /// Whether cached saved books are shown while offline.
  final bool showingOfflineNotice;

  /// Error message shown when loading fails with no cached saved books.
  final String? errorMessage;

  /// Books saved on the active child's bookshelf.
  final List<SavedBook> savedBooks;

  /// Number of saved books currently displayed before "Load more books".
  final int visibleCount;

  /// Predicate returning whether a book ID is saved on the family bookshelf.
  final bool Function(String bookId) isBookSaved;

  /// Book IDs currently undergoing a save or remove request.
  final Set<String> pendingSaveIds;

  /// Callback invoked when the caregiver retries loading saved books.
  final VoidCallback onRetry;

  /// Callback invoked to switch to the Open Library search shelf.
  final VoidCallback onSearchBooks;

  /// Callback invoked when the caregiver removes or saves a book.
  final ValueChanged<BookItem> onToggleSave;

  /// Callback invoked when the caregiver opens the Play Companion dialog.
  final ValueChanged<BookItem> onGetPlayIdea;

  /// Callback invoked when the caregiver taps "Load more books".
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ShelfLoadingSpinner();

    if (errorMessage != null && savedBooks.isEmpty) {
      return ErrorView(message: errorMessage!, onRetry: onRetry);
    }

    if (savedBooks.isEmpty) {
      if (!hasActiveChild) {
        return const EmptyStateView(
          title: 'Choose a child',
          message: 'Select a child to see and save books on their bookshelf.',
          icon: Icons.menu_book_outlined,
        );
      }
      return EmptyStateView(
        title: 'Your bookshelf is empty.',
        message: 'Have favorite books at home? Search Open Library to save bedtime stories or picture books here.',
        icon: Icons.bookmark_border_outlined,
        actionLabel: 'Search books',
        onAction: onSearchBooks,
      );
    }

    final savedItems = savedBooks.map((b) => b.toBook()).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showingOfflineNotice)
          const _ShelfOfflineNotice(message: 'Showing books we saved earlier.'),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space12),
          child: Text(
            '${savedBooks.length} ${savedBooks.length == 1 ? 'saved storybook' : 'saved storybooks'} at home',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        StorybookGrid(
          books: savedItems,
          visibleCount: visibleCount,
          isBookSaved: isBookSaved,
          pendingSaveIds: pendingSaveIds,
          onToggleSave: onToggleSave,
          onGetPlayIdea: onGetPlayIdea,
          onLoadMore: onLoadMore,
        ),
      ],
    );
  }
}

/// Modal dialog presenting full lyrics and play guidance for a [PhilippineRhyme].
class RhymeDetailsDialog extends StatelessWidget {
  /// Creates a [RhymeDetailsDialog].
  const RhymeDetailsDialog({
    super.key,
    required this.rhyme,
    required this.onSchedule,
  });

  /// Rhyme displayed inside the dialog.
  final PhilippineRhyme rhyme;

  /// Callback invoked when the caregiver adds the rhyme to today's plan.
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(rhyme.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rhyme.subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.space16),
            Text(
              rhyme.lyrics.join('\n'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text(
              'How to play: ${rhyme.actionPrompt}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onSchedule();
          },
          child: const Text("Add to today's plan"),
        ),
      ],
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.space8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: onSelected,
        selectedColor: AppColors.forest,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? AppColors.surfaceCard : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ShelfOfflineNotice extends StatelessWidget {
  const _ShelfOfflineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOffline,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textOffline),
      ),
    );
  }
}

class _ShelfLoadingSpinner extends StatelessWidget {
  const _ShelfLoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.space32),
      child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
    );
  }
}
