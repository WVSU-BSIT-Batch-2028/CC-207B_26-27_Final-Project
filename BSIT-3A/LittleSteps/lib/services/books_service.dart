import '../models/book.dart';
import 'api_client.dart';

/// Loads catalog books and manages a child's saved bookshelf.
class BooksService {
  /// Creates a [BooksService].
  BooksService({required this.apiClient});

  static const List<String> _subjects = [
    'picture_books',
    'animals',
    'bedtime',
    'colors',
  ];

  /// Client used for catalog and bookshelf API requests.
  final ApiClient apiClient;

  /// Fetches catalog books for [subject], or merges all subjects when `null`.
  Future<List<BookItem>> fetchBooks({
    String? subject = 'picture_books',
    int limit = 12,
  }) async {
    if (subject == null) {
      final results = await Future.wait(
        _subjects.map((item) => _fetchSubjectBooks(item, limit)),
      );
      final booksById = <String, BookItem>{};
      for (final books in results) {
        for (final book in books) {
          booksById.putIfAbsent(book.id, () => book);
        }
      }
      return booksById.values.toList();
    }

    return _fetchSubjectBooks(subject, limit);
  }

  Future<List<BookItem>> _fetchSubjectBooks(String subject, int limit) async {
    final queryParams = {'limit': limit.toString()};
    queryParams['subject'] = subject;

    final data = await apiClient.get(
      '/api/v1/catalog/books',
      queryParams: queryParams,
    ) as Map<String, dynamic>;

    final booksRaw = data['books'] as List<dynamic>? ?? [];
    return booksRaw
        .map((b) => BookItem.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// Searches the Open Library proxy catalog for books matching [query].
  Future<List<BookItem>> searchBooks(String query, {int limit = 12}) async {
    final queryParams = {'q': query, 'limit': limit.toString()};

    final data = await apiClient.get(
      '/api/v1/catalog/books/search',
      queryParams: queryParams,
    ) as Map<String, dynamic>;

    final booksRaw = data['books'] as List<dynamic>? ?? [];
    return booksRaw
        .map((b) => BookItem.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// Fetches books saved to the bookshelf for [childId].
  Future<List<SavedBook>> fetchSavedBooks(String childId) async {
    final data = await apiClient.get(
      '/api/v1/children/$childId/books',
    ) as Map<String, dynamic>;

    final booksRaw = data['books'] as List<dynamic>? ?? [];
    return booksRaw
        .map((b) => SavedBook.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// Saves [book] to the bookshelf for [childId].
  Future<SavedBook> saveBookToShelf(String childId, BookItem book) async {
    final body = {
      'id': book.id,
      'title': book.title,
      'authors': book.authors,
      if (book.coverUrl != null) 'coverUrl': book.coverUrl,
      'subjects': book.subjects,
    };

    final data = await apiClient.post(
      '/api/v1/children/$childId/books',
      body: body,
    ) as Map<String, dynamic>;

    return SavedBook.fromJson(data);
  }

  /// Removes [bookId] from the bookshelf for [childId].
  Future<void> removeBookFromShelf(String childId, String bookId) async {
    await apiClient.delete('/api/v1/children/$childId/books/$bookId');
  }
}
