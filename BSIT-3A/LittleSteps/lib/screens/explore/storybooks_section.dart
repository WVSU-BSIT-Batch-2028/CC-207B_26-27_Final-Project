import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/age_band.dart';
import '../../models/book.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../models/rhyme.dart';
import '../../services/ai_service.dart';
import '../../services/books_service.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_formatting.dart';
import '../../utils/domain_labels.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/state_views.dart';
import 'play_companion_dialog.dart';
import 'widgets/rhymes_shelf.dart';
import 'widgets/storybooks_shelves.dart';

/// Shelf tabs available inside [StorybooksSection].
enum BookshelfShelf {
  /// Searchable children's catalog sourced from Open Library.
  openLibrary,

  /// Books saved to the active child's family bookshelf.
  ourBookshelf,

  /// Curated traditional Philippine rhymes and singing routines.
  rhymes,
}

/// Explore section hosting Open Library books, saved books, and rhymes.
class StorybooksSection extends StatefulWidget {
  /// Creates a [StorybooksSection].
  const StorybooksSection({
    super.key,
    this.booksService,
    this.catalogService,
    this.aiService,
    this.planService,
    this.activeChild,
    this.selectedShelf = BookshelfShelf.openLibrary,
    this.isOffline = false,
    this.onShelfSelected,
    this.onSavedCountChanged,
    this.onPlanActivity,
  });

  /// Optional books service override used in tests.
  final BooksService? booksService;

  /// Optional catalog service override for fetching live Philippine rhymes.
  final CatalogService? catalogService;

  /// Optional AI service override for generating story play companions.
  final AiService? aiService;

  /// Optional plan service override for scheduling story activities.
  final PlanService? planService;

  /// Currently selected child profile, or `null` when unavailable.
  final Child? activeChild;

  /// Active bookshelf tab to display.
  final BookshelfShelf selectedShelf;

  /// Whether the parent screen is currently offline.
  final bool isOffline;

  /// Callback invoked when the caregiver switches bookshelf tabs.
  final ValueChanged<BookshelfShelf>? onShelfSelected;

  /// Callback invoked whenever the saved books count changes.
  final ValueChanged<int>? onSavedCountChanged;

  /// Callback invoked when a story or rhyme activity is added to today's plan.
  final void Function(Activity activity)? onPlanActivity;

  @override
  State<StorybooksSection> createState() => _StorybooksSectionState();
}

class _StorybooksSectionState extends State<StorybooksSection> {
  static const int _bookPageSize = 8;
  static const int _catalogLimit = 30;
  static const int _searchLimit = 20;

  String? _selectedSubject;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoadingBooks = true;
  bool _initialBooksLoaded = false;
  bool _isLoadingRhymes = false;
  bool _initialRhymesLoaded = false;
  String? _booksError;
  String? _rhymesError;
  bool _showingOfflineBooks = false;
  List<BookItem> _openLibraryBooks = [];
  List<PhilippineRhyme> _rhymes = [];

  bool _isLoadingSaved = false;
  String? _savedBooksError;
  bool _showingSavedBooksOffline = false;
  String? _lastLoadedChildId;
  List<SavedBook> _savedBooks = [];
  final Set<String> _pendingSaves = {};

  int _visibleCatalogCount = _bookPageSize;
  int _visibleSavedCount = _bookPageSize;

  BooksService _resolveBooksService() {
    return widget.booksService ??
        BooksService(apiClient: AuthScope.apiClientOrDefault(context));
  }

  CatalogService _resolveCatalogService() {
    return widget.catalogService ??
        CatalogService(apiClient: _resolveBooksService().apiClient);
  }

  AiService _resolveAiService() {
    return widget.aiService ??
        AiService(apiClient: AuthScope.apiClientOrDefault(context));
  }

  PlanService _resolvePlanService() {
    return widget.planService ??
        PlanService(apiClient: AuthScope.apiClientOrDefault(context));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialBooksLoaded) {
      _initialBooksLoaded = true;
      _loadOpenLibraryBooks();
    }
    if (!_initialRhymesLoaded) {
      _initialRhymesLoaded = true;
      _loadRhymes();
    }
    final childId = widget.activeChild?.id;
    if (_lastLoadedChildId != childId) {
      _lastLoadedChildId = childId;
      _loadSavedBooks();
    }
  }

  @override
  void didUpdateWidget(covariant StorybooksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild?.id != widget.activeChild?.id) {
      _lastLoadedChildId = widget.activeChild?.id;
      _loadSavedBooks();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRhymes() async {
    final canFetch =
        widget.catalogService != null || AuthScope.maybeOf(context) != null;
    if (!canFetch) return;

    setState(() {
      _isLoadingRhymes = true;
      _rhymesError = null;
    });

    try {
      final fetched = await _resolveCatalogService().getRhymes();
      if (!mounted) return;
      setState(() {
        _rhymes = fetched;
        _isLoadingRhymes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRhymes = false;
        if (_rhymes.isEmpty) {
          _rhymesError = 'Could not load rhymes right now. Please check your connection and try again.';
        }
      });
    }
  }

  Future<void> _loadOpenLibraryBooks() async {
    setState(() {
      _isLoadingBooks = true;
      _booksError = null;
    });

    try {
      final service = _resolveBooksService();
      final results = _searchQuery.trim().isNotEmpty
          ? await service.searchBooks(_searchQuery.trim(), limit: _searchLimit)
          : await service.fetchBooks(
              subject: _selectedSubject,
              limit: _catalogLimit,
            );

      if (!mounted) return;
      setState(() {
        _openLibraryBooks = results;
        _visibleCatalogCount = _bookPageSize;
        _isLoadingBooks = false;
        _showingOfflineBooks = widget.isOffline || service.apiClient.isOffline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openLibraryBooks = [];
        _visibleCatalogCount = _bookPageSize;
        _isLoadingBooks = false;
        _showingOfflineBooks = false;
        _booksError = 'Could not load storybooks right now. Please check your connection and try again.';
      });
    }
  }

  Future<void> _loadSavedBooks() async {
    final childId = widget.activeChild?.id;
    final session = AuthScope.maybeOf(context);
    final canFetchSaved =
        widget.booksService != null || (session?.isAuthenticated ?? false);
    if (childId == null || !canFetchSaved) {
      setState(() {
        _savedBooks = [];
        _visibleSavedCount = _bookPageSize;
        _isLoadingSaved = false;
        _savedBooksError = null;
        _showingSavedBooksOffline = false;
      });
      widget.onSavedCountChanged?.call(0);
      return;
    }

    setState(() {
      _isLoadingSaved = true;
      _savedBooksError = null;
    });

    try {
      final service = _resolveBooksService();
      final saved = await service.fetchSavedBooks(childId);
      if (!mounted) return;
      setState(() {
        _savedBooks = saved;
        _visibleSavedCount = _bookPageSize;
        _isLoadingSaved = false;
        _showingSavedBooksOffline =
            widget.isOffline || service.apiClient.isOffline;
      });
      widget.onSavedCountChanged?.call(saved.length);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSaved = false;
        _savedBooksError = 'Your bookshelf could not be loaded. Check your connection and try again.';
      });
    }
  }

  bool _isBookSaved(String bookId) => _savedBooks.any((b) => b.id == bookId);

  Future<void> _handleToggleSave(BookItem book) async {
    final childId = widget.activeChild?.id;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a child to save books.'),
        ),
      );
      return;
    }

    final isCurrentlySaved = _isBookSaved(book.id);
    setState(() => _pendingSaves.add(book.id));

    final service = _resolveBooksService();
    try {
      if (isCurrentlySaved) {
        await service.removeBookFromShelf(childId, book.id);
        if (!mounted) return;
        setState(() {
          _savedBooks.removeWhere((b) => b.id == book.id);
          _pendingSaves.remove(book.id);
        });
        widget.onSavedCountChanged?.call(_savedBooks.length);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${book.title}" from your bookshelf.'),
          ),
        );
      } else {
        final saved = await service.saveBookToShelf(childId, book);
        if (!mounted) return;
        setState(() {
          _savedBooks.insert(0, saved);
          _pendingSaves.remove(book.id);
        });
        widget.onSavedCountChanged?.call(_savedBooks.length);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${book.title}" to your bookshelf.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingSaves.remove(book.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlySaved
                ? 'Could not remove book. Check your connection.'
                : 'Could not save book. Check your connection.',
          ),
        ),
      );
    }
  }

  Future<void> _handleGetPlayIdea(BookItem book) async {
    final childNickname = widget.activeChild?.nickname ?? 'your child';
    final ageBand = widget.activeChild?.ageBand ?? defaultAgeBandCode;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.forest),
                SizedBox(height: AppSpacing.space16),
                Text('Finding play companion idea…'),
              ],
            ),
          ),
        ),
      ),
    );

    var ideaTitle = 'Story & Play: ${book.title}';
    var domain = AppDomains.language;
    var instructions =
        'Read through "${book.title}" together at a gentle pace. Point out pictures of characters and invite $childNickname to mimic their sounds or gestures.';
    var safetyNotice =
        'Always stay close during play and keep small objects out of reach.';
    String? badge = 'Suggested by AI';

    try {
      final res = await _resolveAiService().getStoryActivity(
        bookTitle: book.title,
        subjects: book.subjects,
        ageBand: ageBand,
      );

      final suggestion = res['suggestion'] as Map<String, dynamic>?;
      if (suggestion != null) {
        ideaTitle = suggestion['title'] as String? ?? ideaTitle;
        domain = suggestion['domain'] as String? ?? domain;
        instructions = suggestion['instructions'] as String? ?? instructions;
        safetyNotice = suggestion['safetyNotice'] as String? ?? safetyNotice;
      }
      final provenance = res['provenance'] as Map<String, dynamic>?;
      if (provenance != null) {
        badge = provenance['badge'] as String? ?? badge;
      }
    } catch (_) {
      badge = 'Our pick';
    } finally {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted) return;

    final dialog = PlayCompanionDialog(
      book: book,
      ideaTitle: ideaTitle,
      domain: domain,
      instructions: instructions,
      safetyNotice: safetyNotice,
      badge: badge,
      onAddToPlan: () async {
        Navigator.of(context).pop();
        final activity = PlayCompanionDialog(
          book: book,
          ideaTitle: ideaTitle,
          domain: domain,
          instructions: instructions,
          safetyNotice: safetyNotice,
        ).toActivity(childNickname: widget.activeChild?.nickname);
        await _scheduleActivity(
          activity,
          sourceLabel: 'Storybook companion',
          snackbarTitle: activity.title,
          missingChildMessage:
              'Please select a child profile to schedule activities.',
        );
      },
    );

    showDialog<void>(context: context, builder: (_) => dialog);
  }

  Future<void> _scheduleRhyme(PhilippineRhyme rhyme) async {
    final activity = rhyme.toActivity(
      childNickname: widget.activeChild?.nickname,
    );
    await _scheduleActivity(
      activity,
      sourceLabel: 'Read & Sing Together',
      snackbarTitle: rhyme.title,
      missingChildMessage: 'Please select a child profile to schedule rhymes.',
    );
  }

  Future<void> _scheduleActivity(
    Activity activity, {
    required String sourceLabel,
    required String snackbarTitle,
    required String missingChildMessage,
  }) async {
    if (widget.onPlanActivity != null) {
      widget.onPlanActivity!(activity);
      return;
    }

    final childId = widget.activeChild?.id;
    if (childId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(missingChildMessage)));
      return;
    }

    try {
      await _resolvePlanService().addActivityToPlan(
        childId: childId,
        activityId: activity.id,
        scheduledDate: todayIsoDate(),
        durationMinutes: activity.durationMinutes,
        customActivity: CustomPlanActivity.fromActivity(
          activity,
          sourceLabel: sourceLabel,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$snackbarTitle" to today\'s plan!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to plan right now.')),
        );
      }
    }
  }

  void _showRhymeDetails(PhilippineRhyme rhyme) {
    showDialog<void>(
      context: context,
      builder: (_) => RhymeDetailsDialog(
        rhyme: rhyme,
        onSchedule: () => _scheduleRhyme(rhyme),
      ),
    );
  }

  Widget _buildRhymesShelf() {
    if (_isLoadingRhymes && _rhymes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
      );
    }

    if (_rhymesError != null && _rhymes.isEmpty) {
      return ErrorView(message: _rhymesError!, onRetry: _loadRhymes);
    }

    if (_rhymes.isEmpty) {
      return const EmptyStateView(
        title: 'No rhymes available yet.',
        message: 'Check back soon for traditional songs and rhythm games.',
        icon: Icons.music_note_outlined,
      );
    }

    return RhymesShelf(
      rhymes: _rhymes,
      childNickname: widget.activeChild?.nickname ?? 'your child',
      onShowDetails: _showRhymeDetails,
      onScheduleRhyme: _scheduleRhyme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.selectedShelf == BookshelfShelf.openLibrary)
          OpenLibraryShelf(
            searchController: _searchController,
            searchQuery: _searchQuery,
            selectedSubject: _selectedSubject,
            isLoading: _isLoadingBooks,
            showingOfflineNotice: _showingOfflineBooks,
            errorMessage: _booksError,
            books: _openLibraryBooks,
            visibleCount: _visibleCatalogCount,
            isBookSaved: _isBookSaved,
            pendingSaveIds: _pendingSaves,
            onSearchChanged: (value) {
              setState(() => _searchQuery = value);
              _searchDebounce?.cancel();
              _searchDebounce = Timer(AppMotion.searchDebounce, () {
                if (mounted) _loadOpenLibraryBooks();
              });
            },
            onClearSearch: () {
              _searchDebounce?.cancel();
              _searchController.clear();
              setState(() => _searchQuery = '');
              _loadOpenLibraryBooks();
            },
            onSubjectSelected: (subject) {
              setState(() => _selectedSubject = subject);
              _loadOpenLibraryBooks();
            },
            onRetry: _loadOpenLibraryBooks,
            onShowPictureBooks: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedSubject = 'picture_books';
              });
              _loadOpenLibraryBooks();
            },
            onToggleSave: _handleToggleSave,
            onGetPlayIdea: _handleGetPlayIdea,
            onLoadMore: () =>
                setState(() => _visibleCatalogCount += _bookPageSize),
          )
        else if (widget.selectedShelf == BookshelfShelf.ourBookshelf)
          SavedBookshelfView(
            hasActiveChild: widget.activeChild != null,
            isLoading: _isLoadingSaved,
            showingOfflineNotice: _showingSavedBooksOffline,
            errorMessage: _savedBooksError,
            savedBooks: _savedBooks,
            visibleCount: _visibleSavedCount,
            isBookSaved: _isBookSaved,
            pendingSaveIds: _pendingSaves,
            onRetry: _loadSavedBooks,
            onSearchBooks: () =>
                widget.onShelfSelected?.call(BookshelfShelf.openLibrary),
            onToggleSave: _handleToggleSave,
            onGetPlayIdea: _handleGetPlayIdea,
            onLoadMore: () =>
                setState(() => _visibleSavedCount += _bookPageSize),
          )
        else
          _buildRhymesShelf(),
      ],
    );
  }
}
