import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/milestone.dart';
import 'package:littlesteps/screens/explore/storybooks_section.dart';
import 'package:littlesteps/screens/milestones/milestones_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/books_service.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/services/local_cache.dart';

void main() {
  group('Catalog milestones and rhymes integration', () {
    test(
      'marks milestone and rhyme catalog endpoints public and cacheable',
      () {
        expect(
          ApiClient.isProtectedPath('/api/v1/catalog/milestones'),
          isFalse,
        );
        expect(ApiClient.isProtectedPath('/api/v1/catalog/rhymes'), isFalse);

        final cache = LocalDataCache();
        expect(cache.isCacheablePath('/api/v1/catalog/milestones'), isTrue);
        expect(
          cache.isCacheablePath(
            '/api/v1/catalog/milestones?ageBand=60-71%20months',
          ),
          isTrue,
        );
        expect(cache.isCacheablePath('/api/v1/catalog/rhymes'), isTrue);
        expect(
          cache.isCacheablePath('/api/v1/catalog/rhymes?language=hil'),
          isTrue,
        );
      },
    );

    test(
      'CatalogService parses milestones and rhymes from API responses',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/api/v1/catalog/milestones')) {
            return http.Response(
              jsonEncode({
                'total': 1,
                'items': [
                  {
                    'id': 'lan-60-01',
                    'domain': 'language',
                    'title': 'Retells familiar stories',
                    'lookFor': ['Describes beginning, middle, and end'],
                    'ageBand': '60-71 months',
                    'provenance':
                        'Source: DepEd MATATAG Curriculum - Kindergarten',
                    'status': 'source_checked',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/v1/catalog/rhymes')) {
            return http.Response(
              jsonEncode({
                'total': 1,
                'items': [
                  {
                    'id': 'rhyme-ili-ili-tulog-anay',
                    'title': 'Ili-Ili Tulog Anay',
                    'subtitle': 'Gentle Hiligaynon lullaby',
                    'domain': 'socioEmotional',
                    'domainLabel': 'Feelings',
                    'language': 'hil',
                    'lyrics': ['Ili-ili tulog anay,'],
                    'actionPrompt': 'Sway gently together.',
                    'materials': ['None required'],
                    'durationMinutes': 5,
                    'provenanceSource': 'Hiligaynon Traditional Lullaby',
                    'status': 'source_checked',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        });

        final apiClient = ApiClient(
          baseUrl: 'https://example.test',
          httpClient: mockClient,
        );
        final catalogService = CatalogService(apiClient: apiClient);

        final milestones = await catalogService.getMilestones(
          ageBand: '60-71 months',
        );
        expect(milestones, hasLength(1));
        expect(milestones.first.id, 'lan-60-01');
        expect(milestones.first.domain, MilestoneDomain.language);
        expect(milestones.first.ageBand, '60-71 months');

        final rhymes = await catalogService.getRhymes(language: 'hil');
        expect(rhymes, hasLength(1));
        expect(rhymes.first.id, 'rhyme-ili-ili-tulog-anay');
        expect(rhymes.first.language, 'hil');
        expect(rhymes.first.toActivity().status, 'source_checked');
      },
    );

    testWidgets(
      'MilestonesScreen displays prompts loaded from CatalogService',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'total': 1,
              'items': [
                {
                  'id': 'lan-12-live',
                  'domain': 'language',
                  'title': 'Live API Milestone Prompt',
                  'lookFor': ['Points to a familiar storybook page'],
                  'ageBand': '12-23 months',
                  'provenance': 'Source: ECCD Council NELF (2010)',
                  'status': 'source_checked',
                },
              ],
            }),
            200,
          );
        });

        final catalogService = CatalogService(
          apiClient: ApiClient(
            baseUrl: 'https://example.test',
            httpClient: mockClient,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: MilestonesScreen(catalogService: catalogService)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Live API Milestone Prompt'), findsOneWidget);
      },
    );

    testWidgets(
      'MilestonesScreen shows error state with Retry on API failure',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error":{"code":"SERVER_ERROR"}}', 500);
        });

        final catalogService = CatalogService(
          apiClient: ApiClient(
            baseUrl: 'https://example.test',
            httpClient: mockClient,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: MilestonesScreen(catalogService: catalogService)),
        );
        await tester.pumpAndSettle();

        expect(find.text("We couldn't load this right now"), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'MilestonesScreen shows error state with Retry on API failure',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error":{"code":"SERVER_ERROR"}}', 500);
        });

        final catalogService = CatalogService(
          apiClient: ApiClient(
            baseUrl: 'https://example.test',
            httpClient: mockClient,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: MilestonesScreen(catalogService: catalogService)),
        );
        await tester.pumpAndSettle();

        expect(find.text("We couldn't load this right now"), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'StorybooksSection rhymes shelf renders rhymes from CatalogService',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/api/v1/catalog/rhymes')) {
            return http.Response(
              jsonEncode({
                'total': 1,
                'items': [
                  {
                    'id': 'rhyme-live-test',
                    'title': 'Live API Hiligaynon Song',
                    'subtitle': 'Fetched directly from Firestore catalog',
                    'domain': 'socioEmotional',
                    'domainLabel': 'Feelings',
                    'language': 'hil',
                    'lyrics': ['Ili-ili tulog anay,'],
                    'actionPrompt': 'Sway gently together.',
                    'materials': ['None required'],
                    'durationMinutes': 5,
                    'provenanceSource': 'Hiligaynon Traditional Lullaby',
                    'status': 'source_checked',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'subject': 'picture_books',
              'totalCount': 0,
              'books': <dynamic>[],
              'provenance': {'source': 'Open Library'},
            }),
            200,
          );
        });

        final apiClient = ApiClient(
          baseUrl: 'https://example.test',
          httpClient: mockClient,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StorybooksSection(
                  booksService: BooksService(apiClient: apiClient),
                  catalogService: CatalogService(apiClient: apiClient),
                  selectedShelf: BookshelfShelf.rhymes,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Live API Hiligaynon Song'), findsOneWidget);
      },
    );

    testWidgets(
      'StorybooksSection rhymes shelf shows retry state when API fails',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error":{"code":"SERVER_ERROR"}}', 500);
        });

        final apiClient = ApiClient(
          baseUrl: 'https://example.test',
          httpClient: mockClient,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StorybooksSection(
                  booksService: BooksService(apiClient: apiClient),
                  catalogService: CatalogService(apiClient: apiClient),
                  selectedShelf: BookshelfShelf.rhymes,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Could not load rhymes right now'),
          findsOneWidget,
        );
      },
    );
  });
}
