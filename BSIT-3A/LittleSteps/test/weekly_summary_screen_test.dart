import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/models/summary.dart';
import 'package:littlesteps/screens/reflection/weekly_summary_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/services/summary_service.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

import 'fixtures/sample_weekly_summaries.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return const AuthUser(
      id: 'u1',
      email: 'caregiver@example.com',
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return const AuthUser(
      id: 'u1',
      email: 'caregiver@example.com',
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<AuthUser> refreshToken(String refreshToken) async {
    return const AuthUser(
      id: 'u1',
      email: 'caregiver@example.com',
      idToken: 'token',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  Widget createTestWidget({
    WeeklySummaryViewState state = WeeklySummaryViewState.ready,
    String initialWeek = '2026-W43',
    Map<String, WeeklySummary>? summaries,
  }) {
    return MaterialApp(
      home: WeeklySummaryScreen(
        initialState: state,
        initialWeek: initialWeek,
        summaries: summaries ?? sampleWeeklySummaries,
      ),
    );
  }

  group('WeeklySummaryScreen UI & State Tests', () {
    testWidgets('renders populated week stats and disclaimer', (tester) async {
      await tester.pumpWidget(createTestWidget(initialWeek: '2026-W43'));
      await tester.pumpAndSettle();

      // Heading & Child selector
      expect(find.text('This week'), findsOneWidget);
      expect(
        find.text('A look back at the moments you wrote down.'),
        findsOneWidget,
      );
      expect(find.text('For Maya · 14 months'), findsOneWidget);

      // Stat cards: 4 activities, 1 milestone
      expect(find.text('4'), findsOneWidget);
      expect(find.text('activities\ncompleted'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('milestone\nnoticed'), findsOneWidget);

      // Non-diagnostic disclaimer
      expect(
        find.textContaining('Based only on what you wrote down.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('never compares Maya with other children.'),
        findsOneWidget,
      );

      // Domain breakdowns
      expect(find.text('Everyday play areas'), findsOneWidget);
      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('1 activity'), findsNWidgets(2));
      expect(find.text('Talking'), findsOneWidget);
      expect(find.text('2 activities'), findsOneWidget);
      expect(find.text('Feelings'), findsOneWidget);
      expect(find.text('None this week'), findsOneWidget);

      // Reflection prompt card
      expect(find.text('Something to try'), findsOneWidget);
      expect(
        find.text(
          'Maya enjoyed talking games this week. Next time you read together, pause on a page and let her point first.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('An idea for play, not a goal to meet.'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty week state when zero activities recorded', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(initialWeek: '2026-W41'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing recorded this week yet'), findsOneWidget);
      expect(
        find.text(
          "This fills in when you finish an activity or note a milestone. There's no daily goal and nothing to catch up on.",
        ),
        findsOneWidget,
      );
      expect(find.text('Find a 10-minute idea'), findsOneWidget);
    });

    testWidgets('switches between weeks using week picker', (tester) async {
      await tester.pumpWidget(createTestWidget(initialWeek: '2026-W43'));
      await tester.pumpAndSettle();

      // Initially shows populated week
      expect(find.text('4'), findsOneWidget);

      // Tap week picker
      await tester.tap(find.text('Oct 19 – 25, 2026'));
      await tester.pumpAndSettle();

      // Tap empty week (Oct 5 – 11, 2026)
      await tester.tap(find.text('Oct 5 – 11, 2026').last);
      await tester.pumpAndSettle();

      // Shows empty week card
      expect(find.text('Nothing recorded this week yet'), findsOneWidget);
    });

    testWidgets('displays error state with retry button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: WeeklySummaryViewState.error),
      );
      await tester.pumpAndSettle();

      expect(find.text("We couldn't load this right now"), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('displays offline banner in offline state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: WeeklySummaryViewState.offline),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're offline"), findsOneWidget);
    });

    testWidgets('strict non-diagnostic banned words audit', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      const bannedWords = [
        'delayed',
        'behind',
        'on track',
        'normal',
        'abnormal',
        'score',
        'pass',
        'fail',
      ];

      for (final summary in sampleWeeklySummaries.values) {
        for (final word in bannedWords) {
          expect(
            summary.reflectionPrompt.toLowerCase().contains(word),
            isFalse,
            reason: 'Reflection contains banned word "$word"',
          );
        }
      }
    });

    testWidgets('clears cached summaries and selected week on child switch', (
      tester,
    ) async {
      final childMaya = Child(
        id: 'child-maya',
        nickname: 'Maya',
        ageBand: '12-23m',
        birthMonthYear: '2025-05',
        createdAt: DateTime(2025, 5, 1),
        updatedAt: DateTime(2025, 5, 1),
      );
      final childLeo = Child(
        id: 'child-leo',
        nickname: 'Leo',
        ageBand: '6-11m',
        birthMonthYear: '2026-05',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/summary/weekly')) {
          final isMaya = request.url.path.contains('child-maya');
          return http.Response(
            jsonEncode({
              'id': '2026-W43',
              'weekStartDate': '2026-10-19',
              'weekEndDate': '2026-10-25',
              'completedActivityCount': isMaya ? 4 : 2,
              'observedMilestoneCount': 1,
              'totalPlannedActivities': isMaya ? 6 : 2,
              'domainDistribution': {'language': isMaya ? 2 : 1},
              'topActivityIds': ['act-1'],
              'reflectionPrompt': isMaya
                  ? 'Maya enjoyed talking games this week.'
                  : 'Leo enjoyed exploring tummy time.',
              'generatedAt': '2026-10-25T18:00:00.000Z',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test',
        httpClient: mockClient,
      );
      final summaryService = SummaryService(apiClient: apiClient);
      final sessionState = AuthSessionState(authService: _FakeAuthService());
      sessionState.setActiveChild(childMaya);

      await tester.pumpWidget(
        AuthScope(
          sessionState: sessionState,
          apiClient: apiClient,
          child: MaterialApp(
            home: WeeklySummaryScreen(summaryService: summaryService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('For Maya · 12-23 months'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(
        find.text('Maya enjoyed talking games this week.'),
        findsOneWidget,
      );

      // Switch active child to Leo
      sessionState.setActiveChild(childLeo);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('For Leo · 6-11 months'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Leo enjoyed exploring tummy time.'), findsOneWidget);
      expect(find.text('Maya enjoyed talking games this week.'), findsNothing);
    });
  });
}
