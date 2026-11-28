import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/book.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/books_service.dart';
import 'package:littlesteps/services/local_cache.dart';

void main() {
  group('BooksService & SavedBook', () {
    test('SavedBook serializes and deserializes correctly', () {
      final now = DateTime.utc(2026, 11, 24, 8, 30);
      final saved = SavedBook(
        id: 'OL52987W',
        childId: 'child-123',
        title: 'The Very Hungry Caterpillar',
        authors: const ['Eric Carle'],
        coverUrl: 'https://covers.openlibrary.org/b/id/7835968-M.jpg',
        subjects: const ['picture books', 'animals'],
        createdAt: now,
        updatedAt: now,
      );

      final json = saved.toJson();
      final decoded = SavedBook.fromJson(json);

      expect(decoded.id, 'OL52987W');
      expect(decoded.childId, 'child-123');
      expect(decoded.title, 'The Very Hungry Caterpillar');
      expect(decoded.authors, ['Eric Carle']);
      expect(decoded.subjects, ['picture books', 'animals']);
      expect(decoded.toBook().id, 'OL52987W');
    });

    test(
      'fetchBooks calls /api/v1/catalog/books with subject and limit',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/catalog/books');
          expect(request.url.queryParameters['subject'], 'bedtime');
          expect(request.url.queryParameters['limit'], '10');
          return http.Response(
            jsonEncode({
              'books': [
                {
                  'id': 'OL151798W',
                  'title': 'Goodnight Moon',
                  'authors': ['Margaret Wise Brown'],
                  'coverUrl': 'https://covers.openlibrary.org/b/id/35556-M.jpg',
                  'subjects': ['bedtime', 'picture books'],
                },
              ],
            }),
            200,
          );
        });

        final service = BooksService(
          apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
        );

        final books = await service.fetchBooks(subject: 'bedtime', limit: 10);
        expect(books.length, 1);
        expect(books.first.title, 'Goodnight Moon');
      },
    );

    test('searchBooks calls /api/v1/catalog/books/search with query', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/catalog/books/search');
        expect(request.url.queryParameters['q'], 'caterpillar');
        return http.Response(
          jsonEncode({
            'books': [
              {
                'id': 'OL52987W',
                'title': 'The Very Hungry Caterpillar',
                'authors': ['Eric Carle'],
                'subjects': ['picture books'],
              },
            ],
          }),
          200,
        );
      });

      final service = BooksService(
        apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
      );

      final books = await service.searchBooks('caterpillar');
      expect(books.length, 1);
      expect(books.first.title, 'The Very Hungry Caterpillar');
    });

    test('fetchSavedBooks, saveBookToShelf, and removeBookFromShelf call child bookshelf routes', () async {
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'books': [
                {
                  'id': 'OL52987W',
                  'childId': 'child-c1',
                  'title': 'The Very Hungry Caterpillar',
                  'authors': ['Eric Carle'],
                  'subjects': ['animals'],
                  'createdAt': '2026-11-24T00:00:00.000Z',
                  'updatedAt': '2026-11-24T00:00:00.000Z',
                },
              ],
            }),
            200,
          );
        } else if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              ...body,
              'childId': 'child-c1',
              'createdAt': '2026-11-24T00:00:00.000Z',
              'updatedAt': '2026-11-24T00:00:00.000Z',
            }),
            201,
          );
        } else if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final service = BooksService(
        apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
      );

      final savedList = await service.fetchSavedBooks('child-c1');
      expect(savedList.length, 1);

      final newBook = const Book(
        id: 'OL151798W',
        title: 'Goodnight Moon',
        authors: ['Margaret Wise Brown'],
        subjects: ['bedtime'],
      );
      final saved = await service.saveBookToShelf('child-c1', newBook);
      expect(saved.id, 'OL151798W');

      await service.removeBookFromShelf('child-c1', 'OL151798W');

      expect(calls, [
        'GET /api/v1/children/child-c1/books',
        'POST /api/v1/children/child-c1/books',
        'DELETE /api/v1/children/child-c1/books/OL151798W',
      ]);
    });

    test('cached saved books remain available when offline', () async {
      final cache = LocalDataCache();
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'books': [
              {
                'id': 'OL52987W',
                'childId': 'child-c1',
                'title': 'The Very Hungry Caterpillar',
                'authors': ['Eric Carle'],
                'subjects': ['picture books'],
                'createdAt': '2026-11-24T00:00:00.000Z',
                'updatedAt': '2026-11-24T00:00:00.000Z',
              },
            ],
            'totalCount': 1,
          }),
          200,
        );
      });
      final apiClient = ApiClient(
        baseUrl: 'http://test',
        httpClient: client,
        cache: cache,
      );
      final service = BooksService(apiClient: apiClient);

      expect((await service.fetchSavedBooks('child-c1')).length, 1);
      apiClient.isOffline = true;
      final cachedBooks = await service.fetchSavedBooks('child-c1');

      expect(cachedBooks.single.title, 'The Very Hungry Caterpillar');
      expect(requestCount, 1);
    });
  });
}
