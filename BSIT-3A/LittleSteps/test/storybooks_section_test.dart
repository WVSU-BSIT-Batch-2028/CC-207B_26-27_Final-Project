import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/explore/explore_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/services/plan_service.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

class _TestAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AuthUser(id: 'caregiver-1', email: email, idToken: 'token');

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> refreshToken(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'shows storybook shelves, saves a book, and plans its fallback play idea',
    (tester) async {
      final savedBooks = <Map<String, dynamic>>[];
      final planRequests = <Map<String, dynamic>>[];
      final apiClient = ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'GET' && path == '/api/v1/catalog/activities') {
            return http.Response(jsonEncode({'items': []}), 200);
          }
          if (request.method == 'GET' && path == '/api/v1/catalog/books') {
            return http.Response(
              jsonEncode({
                'books': [
                  {
                    'id': 'OL52987W',
                    'title': 'The Very Hungry Caterpillar',
                    'authors': ['Eric Carle'],
                    'subjects': ['Picture books', 'Animals'],
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'GET' &&
              path == '/api/v1/children/child-c1/books') {
            return http.Response(
              jsonEncode({
                'books': savedBooks,
                'totalCount': savedBooks.length,
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              path == '/api/v1/children/child-c1/books') {
            final now = '2026-11-24T00:00:00.000Z';
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final saved = {
              ...body,
              'childId': 'child-c1',
              'createdAt': now,
              'updatedAt': now,
            };
            savedBooks.add(saved);
            return http.Response(jsonEncode(saved), 201);
          }
          if (request.method == 'POST' && path == '/api/v1/ai/story-activity') {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'SERVICE_UNAVAILABLE',
                  'message': 'Please try again in a moment.',
                },
              }),
              503,
            );
          }
          if (request.method == 'POST' &&
              path == '/api/v1/children/child-c1/plans') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            planRequests.add(body);
            final now = '2026-11-24T00:00:00.000Z';
            return http.Response(
              jsonEncode({
                'id': 'plan-1',
                'childId': 'child-c1',
                ...body,
                'status': 'planned',
                'createdAt': now,
                'updatedAt': now,
              }),
              201,
            );
          }
          return http.Response('Not Found', 404);
        }),
      );
      final session = AuthSessionState(authService: _TestAuthService());
      await session.signIn(email: 'caregiver@example.com', password: 'test');
      session.setActiveChild(
        Child(
          id: 'child-c1',
          nickname: 'Maya',
          ageBand: '12-23m',
          createdAt: DateTime.utc(2026, 1),
          updatedAt: DateTime.utc(2026, 1),
        ),
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScope(
            sessionState: session,
            apiClient: apiClient,
            child: Scaffold(
              body: ExploreScreen(
                catalogService: CatalogService(apiClient: apiClient),
                planService: PlanService(apiClient: apiClient),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Storybooks'));
      await tester.pumpAndSettle();
      expect(find.text('The Very Hungry Caterpillar'), findsWidgets);
      expect(find.text('Books from Open Library'), findsNothing);
      expect(find.text('Our Bookshelf'), findsOneWidget);
      expect(find.text('Read & Sing Together'), findsOneWidget);

      final semantics = tester.ensureSemantics();
      final saveLabel = find.bySemanticsLabel(
        'Save "The Very Hungry Caterpillar" to bookshelf',
      );
      expect(saveLabel, findsOneWidget);
      await tester.tap(saveLabel);
      await tester.pumpAndSettle();
      expect(savedBooks, hasLength(1));

      await tester.tap(find.text('Our Bookshelf'));
      await tester.pumpAndSettle();
      expect(find.text('1 saved storybook at home'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Remove "The Very Hungry Caterpillar" from bookshelf',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Storybooks'));
      await tester.pumpAndSettle();
      final playButton = find.text('Get a play idea');
      await tester.ensureVisible(playButton);
      await tester.pumpAndSettle();
      await tester.tap(playButton);
      await tester.pumpAndSettle();
      expect(find.text('Our pick'), findsOneWidget);
      expect(find.text("Add to today's plan"), findsOneWidget);

      await tester.tap(find.text("Add to today's plan"));
      await tester.pumpAndSettle();
      expect(planRequests, hasLength(1));
      expect(planRequests.single['activityId'], 'story-ol52987w');
      semantics.dispose();
    },
  );
}
