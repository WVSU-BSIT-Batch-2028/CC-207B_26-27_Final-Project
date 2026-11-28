import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/ai/ai_suggestions_screen.dart';
import 'package:littlesteps/services/api_client.dart';

void main() {
  final testChild = Child(
    id: 'child-123',
    nickname: 'Maya',
    ageBand: '12-23m',
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
  );

  final sampleAiSuccessResponse = {
    'suggestions': [
      {
        'activityId': 'act-cups-tower',
        'title': 'Build a Cup Tower',
        'whyPicked':
            'Matches your available cups and encourages fine motor stacking.',
        'activity': {
          'id': 'act-cups-tower',
          'title': 'Build a Cup Tower',
          'type': 'activity',
          'language': 'en',
          'domain': 'motor',
          'ageBand': '12-23m',
          'durationMinutes': 15,
          'durationEstimate': '15 mins',
          'setting': 'indoor',
          'materials': ['paper cups'],
          'instructions': [
            'Place cups on the floor.',
            'Show how to stack one over the other.',
            'Celebrate when knocked down gently.',
          ],
          'limitations': 'Supervise closely.',
          'status': 'reviewed_approved',
          'provenanceSource': 'LittleSteps Catalog',
        },
      },
    ],
    'source': 'ai',
    'tier': 1,
    'provenance': {
      'badge': 'Suggested by AI',
      'label': null,
      'disclaimer':
          'Observational play suggestion only. Not developmental assessment.',
      'model': 'gemini-flash-lite-latest',
      'reviewed': true,
    },
  };

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders input form with privacy notice and choice options', (
    tester,
  ) async {
    configureViewport(tester);

    final client = MockClient((request) async {
      return http.Response(jsonEncode({}), 200);
    });
    final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: apiClient,
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idea helper'), findsWidgets);
    expect(find.text('How much time do you have?'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('Where will you play?'), findsOneWidget);
    expect(find.text('Indoor or outdoor'), findsOneWidget);
    expect(find.text('What do you have at home?'), findsOneWidget);
    expect(
      find.text('Materials only, no names. Comma-separated.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'We send only: time, setting, materials, and age band. Child names and notes are never sent.',
      ),
      findsOneWidget,
    );
    expect(find.text('Find play ideas'), findsOneWidget);
  });

  testWidgets(
    'submits request without child name and displays AI suggestion with badge and disclaimer',
    (tester) async {
      configureViewport(tester);

      http.Request? capturedRequest;

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          capturedRequest = request;
          return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: apiClient,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'paper cups, spoon');
      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['materials'], ['paper cups', 'spoon']);
      expect(body['timeMinutes'], 15);
      expect(body['setting'], 'either');
      expect(body['ageBand'], '12-23m');
      expect(body.containsKey('nickname'), isFalse);
      expect(body.containsKey('childName'), isFalse);
      expect(capturedRequest!.body.contains('Maya'), isFalse);

      expect(find.text('Suggested by AI'), findsOneWidget);
      expect(
        find.text(
          'Suggested by AI: always adapt activities to your child and ensure adult supervision.',
        ),
        findsOneWidget,
      );
      expect(find.text('Build a Cup Tower'), findsOneWidget);
      expect(find.text('15 mins · Indoor'), findsOneWidget);
      expect(find.textContaining('Item ID:'), findsNothing);
      expect(
        find.text(
          'Why this fits: Matches your available cups and encourages fine motor stacking.',
        ),
        findsOneWidget,
      );
      expect(find.text('Materials needed:'), findsOneWidget);
      expect(find.text('paper cups'), findsOneWidget);
      expect(find.text('Steps to play:'), findsOneWidget);
      expect(find.text("Add to today's plan"), findsOneWidget);
      expect(find.text('Generate another'), findsOneWidget);
      expect(find.text('Edit preferences'), findsOneWidget);

      await tester.ensureVisible(find.text('Edit preferences'));
      await tester.tap(find.text('Edit preferences'));
      await tester.pumpAndSettle();
      expect(find.text('Idea helper'), findsWidgets);
      expect(find.byType(TextFormField), findsOneWidget);
    },
  );

  testWidgets(
    'preselects initialSetting and sends it in recommendation payload',
    (tester) async {
      configureViewport(tester);

      http.Request? capturedRequest;
      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          capturedRequest = request;
          return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
            initialChild: testChild,
            initialSetting: 'outdoor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final outdoorChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Outdoor'),
      );
      expect(outdoorChip.selected, isTrue);

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['setting'], 'outdoor');
    },
  );

  testWidgets(
    'displays rate-limited state on HTTP 429 with catalog link and safe fallback',
    (tester) async {
      configureViewport(tester);

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'RATE_LIMITED',
                'message': 'Rate limit exceeded.',
              },
            }),
            429,
          );
        }
        if (request.url.path.contains('/catalog/activities')) {
          return http.Response(
            jsonEncode({
              'items': [
                (sampleAiSuccessResponse['suggestions'] as List)
                    .first['activity'],
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: apiClient,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Taking a short break'), findsOneWidget);
      expect(
        find.text(
          "Let's take a short break. You've asked for many ideas in a row. Please wait a minute, then try again.",
        ),
        findsOneWidget,
      );
      expect(find.text('Back to activities'), findsOneWidget);
      expect(find.text('Catalog picks · not AI'), findsOneWidget);
      expect(find.text('Suggested by AI'), findsNothing);
    },
  );

  testWidgets(
    'handles server error gracefully with catalog fallback labeled without AI badge',
    (tester) async {
      configureViewport(tester);

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response('Server Error', 500);
        }
        if (request.url.path.contains('/catalog/activities')) {
          return http.Response(
            jsonEncode({
              'items': [
                (sampleAiSuccessResponse['suggestions'] as List)
                    .first['activity'],
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: apiClient,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Using our activity list'), findsOneWidget);
      expect(find.text('Catalog picks · not AI'), findsOneWidget);
      expect(
        find.text(
          'AI suggestions are unavailable right now. Here are reviewed play ideas for this age.',
        ),
        findsOneWidget,
      );
      expect(find.text('Suggested by AI'), findsNothing);
      expect(find.text('Build a Cup Tower'), findsOneWidget);
      expect(find.text("Add to today's plan"), findsWidgets);
    },
  );

  testWidgets('adds suggestion to today plan and shows SnackBar', (
    tester,
  ) async {
    configureViewport(tester);

    String? addedActivityId;

    final client = MockClient((request) async {
      if (request.url.path.contains('/api/v1/ai/recommendations')) {
        return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
      }
      if (request.url.path.contains('/plans') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        addedActivityId = body['activityId'] as String?;
        return http.Response(
          jsonEncode({
            'id': 'plan-1',
            'childId': testChild.id,
            'activityId': addedActivityId,
            'scheduledDate': body['scheduledDate'],
            'status': 'planned',
            'createdAt': '2026-11-18T00:00:00Z',
            'updatedAt': '2026-11-18T00:00:00Z',
          }),
          201,
        );
      }
      return http.Response(jsonEncode({}), 200);
    });

    final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: apiClient,
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find play ideas'));
    await tester.tap(find.text('Find play ideas'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Add to today's plan").first);
    await tester.tap(find.text("Add to today's plan").first);
    await tester.pumpAndSettle();

    expect(addedActivityId, 'act-cups-tower');
    expect(
      find.text('Added "Build a Cup Tower" to today\'s plan'),
      findsOneWidget,
    );
  });

  testWidgets('displays loading state during pending request', (tester) async {
    configureViewport(tester);

    final completer = Completer<http.Response>();
    final client = MockClient((request) async => completer.future);
    final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: apiClient,
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find play ideas'));
    await tester.tap(find.text('Find play ideas'));
    await tester.pump();

    expect(
      find.text('Finding ideas… This usually takes a few seconds.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(http.Response(jsonEncode(sampleAiSuccessResponse), 200));
    await tester.pumpAndSettle();
    expect(find.text('Suggested by AI'), findsOneWidget);
  });

  testWidgets('disables Add to plan when no child is selected', (tester) async {
    configureViewport(tester);

    final client = MockClient((request) async {
      if (request.url.path.contains('/api/v1/ai/recommendations')) {
        return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
      }
      return http.Response(jsonEncode({}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Find play ideas'));
    await tester.tap(find.text('Find play ideas'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a child to add this to a plan.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "Add to today's plan"),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'shows Play Block summary and idempotent Add all for 45 min requests',
    (tester) async {
      configureViewport(tester);

      final addedIds = <String>[];
      final twoActivitiesResponse = {
        'source': 'ai',
        'tier': 1,
        'provenance': {
          'badge': 'Suggested by AI',
          'disclaimer': 'Observational play suggestion only. Not developmental assessment.',
        },
        'suggestions': [
          {
            'activityId': 'act-003',
            'title': 'Cushion Mountain Crawl',
            'whyPicked': 'Builds balance safely indoors.',
            'activity': {
              'id': 'act-003',
              'title': 'Cushion Mountain Crawl',
              'type': 'activity',
              'language': 'en',
              'domain': 'motor',
              'ageBand': '12-23m',
              'durationMinutes': 15,
              'durationEstimate': '10-15 mins',
              'setting': 'indoor',
              'materials': ['cushions'],
              'instructions': ['Stack pillows.'],
              'limitations': 'Supervise closely.',
              'status': 'reviewed_approved',
              'provenanceSource': 'ECCD Council',
            },
          },
          {
            'activityId': 'act-008',
            'title': 'Stack the Plastic Cups',
            'whyPicked': 'Supports hand-eye coordination.',
            'activity': {
              'id': 'act-008',
              'title': 'Stack the Plastic Cups',
              'type': 'activity',
              'language': 'en',
              'domain': 'cognitive',
              'ageBand': '12-23m',
              'durationMinutes': 10,
              'durationEstimate': '10 mins',
              'setting': 'indoor',
              'materials': ['plastic cups'],
              'instructions': ['Stack cups.'],
              'limitations': 'Supervise closely.',
              'status': 'reviewed_approved',
              'provenanceSource': 'ECCD Council',
            },
          },
        ],
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response(jsonEncode(twoActivitiesResponse), 200);
        }
        if (request.url.path.contains('/plans') && request.method == 'GET') {
          // Pretend act-008 is already scheduled today to test idempotency.
          return http.Response(
            jsonEncode([
              {
                'id': 'plan-existing',
                'childId': 'c1',
                'activityId': 'act-008',
                'scheduledDate': '2026-11-24',
                'status': 'planned',
                'createdAt': '2026-11-24T08:00:00.000Z',
                'updatedAt': '2026-11-24T08:00:00.000Z',
              },
            ]),
            200,
          );
        }
        if (request.url.path.contains('/plans') && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          addedIds.add(body['activityId'] as String);
          return http.Response(
            jsonEncode({
              'id': 'plan-new',
              'childId': 'c1',
              'activityId': body['activityId'],
              'scheduledDate': body['scheduledDate'],
              'status': 'planned',
              'createdAt': '2026-11-24T08:00:00.000Z',
              'updatedAt': '2026-11-24T08:00:00.000Z',
            }),
            201,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('45 min'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Suggested by AI'), findsOneWidget);
      expect(find.text('Play block for 45 min'), findsOneWidget);
      expect(
        find.textContaining('2 short reviewed activities (~25 mins total)'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text("Add all to today's plan"));
      await tester.tap(find.text("Add all to today's plan"));
      await tester.pumpAndSettle();

      // Only act-003 should be posted since act-008 was already on today's plan.
      expect(addedIds, ['act-003']);
      expect(find.text("All added to today's plan"), findsOneWidget);
    },
  );

  testWidgets(
    'HTTP 200 empty fallback response automatically populates catalog picks',
    (tester) async {
      configureViewport(tester);

      final emptyFallbackResponse = {
        'isAiGenerated': false,
        'suggestions': [],
        'disclaimer':
            'Observational play suggestion only. Not developmental assessment.',
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response(jsonEncode(emptyFallbackResponse), 200);
        }
        if (request.url.path.contains('/catalog/activities')) {
          return http.Response(
            jsonEncode({
              'items': [
                (sampleAiSuccessResponse['suggestions'] as List)
                    .first['activity'],
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Using our activity list'), findsOneWidget);
      expect(find.text('Catalog picks · not AI'), findsOneWidget);
      expect(
        find.text(
          'AI suggestions are unavailable right now. Here are reviewed play ideas for this age.',
        ),
        findsOneWidget,
      );
      expect(find.text('Build a Cup Tower'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'Total empty fallback renders clean empty recovery message when catalog is empty',
    (tester) async {
      configureViewport(tester);

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response('Server Error', 500);
        }
        if (request.url.path.contains('/catalog/activities')) {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Using our activity list'), findsOneWidget);
      expect(
        find.text(
          'AI suggestions are unavailable right now, and no matching activities could be loaded.',
        ),
        findsOneWidget,
      );
      expect(find.text('No matching play ideas yet'), findsOneWidget);
      expect(
        find.text(
          'Try changing the time, setting, or language, or tap Try again once your connection is ready.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'renders Hybrid ai_custom suggestion with materialNote, Material adaptation badge, and schedulable custom plan CTA',
    (tester) async {
      configureViewport(tester);

      Map<String, dynamic>? postedPlanBody;
      final customResponse = {
        'source': 'ai_custom',
        'tier': 1,
        'materialNote': 'Using banana for safe supervised play; skipped shampoo because it is not safe for toddlers to mouth.',
        'provenance': {
          'badge': 'Suggested by AI',
          'label': 'Material adaptation',
          'disclaimer': 'Observational play suggestion only. Not developmental assessment.',
          'model': 'gemini-3.5-flash-lite',
          'reviewed': false,
        },
        'suggestions': [
          {
            'activityId': 'custom-1',
            'title': 'Banana Peel and Squish Play',
            'whyPicked':
                'Uses your banana for gentle supervised indoor sensory play.',
            'isCustom': true,
            'activity': {
              'id': 'custom-1',
              'title': 'Banana Peel and Squish Play',
              'type': 'activity',
              'language': 'en',
              'domain': 'motor',
              'ageBand': '12-23m',
              'durationMinutes': 10,
              'durationEstimate': '10 mins',
              'setting': 'indoor',
              'materials': ['banana'],
              'instructions': [
                'Peel a ripe banana together on a clean plate.',
                'Let your toddler squish soft slices with fingers.',
              ],
              'limitations':
                  'Stay close and slice banana into soft bite-sized pieces.',
              'status': 'synthetic_fixture',
              'provenanceSource': '',
            },
          },
        ],
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['allowCustom'], isTrue);
          return http.Response(jsonEncode(customResponse), 200);
        }
        if (request.url.path.contains('/plans') && request.method == 'POST') {
          postedPlanBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'plan-custom-1',
              'childId': testChild.id,
              'activityId': postedPlanBody!['activityId'],
              'scheduledDate': postedPlanBody!['scheduledDate'],
              'status': 'planned',
              'durationMinutes': postedPlanBody!['durationMinutes'],
              'customActivity': postedPlanBody!['customActivity'],
              'createdAt': '2026-11-25T09:00:00Z',
              'updatedAt': '2026-11-25T09:00:00Z',
            }),
            201,
          );
        }
        if (request.url.path.contains('/plans') && request.method == 'GET') {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'banana, shampoo');
      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Suggested by AI'), findsOneWidget);
      expect(
        find.text(
          'Custom idea tailored to your materials; not from the reviewed catalog.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('1 short play idea'), findsOneWidget);
      expect(find.textContaining('reviewed activity'), findsNothing);
      expect(find.textContaining('skipped shampoo'), findsOneWidget);
      expect(find.text('Material adaptation'), findsOneWidget);
      expect(find.text('Banana Peel and Squish Play'), findsOneWidget);
      expect(
        find.text(
          'Safety note: Stay close and slice banana into soft bite-sized pieces.',
        ),
        findsOneWidget,
      );
      expect(find.text("Add to today's plan"), findsOneWidget);

      await tester.ensureVisible(find.text("Add to today's plan"));
      await tester.tap(find.text("Add to today's plan"));
      await tester.pumpAndSettle();

      expect(postedPlanBody, isNotNull);
      expect(
        postedPlanBody!['activityId'],
        'custom-banana-peel-and-squish-play',
      );
      expect(
        (postedPlanBody!['customActivity'] as Map<String, dynamic>)['title'],
        'Banana Peel and Squish Play',
      );
      expect(
        (postedPlanBody!['customActivity']
            as Map<String, dynamic>)['sourceLabel'],
        'Material adaptation',
      );
      expect(find.text("Added to today's plan"), findsOneWidget);
    },
  );

  testWidgets('shows connection-specific SnackBar when offline add fails', (
    tester,
  ) async {
    configureViewport(tester);

    final client = MockClient((request) async {
      if (request.url.path.contains('/api/v1/ai/recommendations')) {
        return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
      }
      if (request.url.path.contains('/plans') && request.method == 'POST') {
        throw http.ClientException('Network unavailable');
      }
      return http.Response(jsonEncode({}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: ApiClient(baseUrl: 'http://test', httpClient: client),
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find play ideas'));
    await tester.tap(find.text('Find play ideas'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Add to today's plan").first);
    await tester.tap(find.text("Add to today's plan").first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Could not add this to today's plan. Check your connection and try again.",
      ),
      findsOneWidget,
    );
  });
}
