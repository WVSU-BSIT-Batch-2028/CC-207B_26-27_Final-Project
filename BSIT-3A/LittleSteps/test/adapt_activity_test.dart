import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/activity.dart';
import 'package:littlesteps/models/recommendation.dart';
import 'package:littlesteps/screens/explore/activity_detail_screen.dart';
import 'package:littlesteps/services/ai_service.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/theme/app_theme.dart';
import 'package:littlesteps/utils/material_labels.dart';

Activity _sampleActivity() => const Activity(
  id: 'act-stack-cups',
  title: 'Stack the cups',
  type: 'activity',
  language: 'en',
  setting: 'indoor',
  ageBand: '12-23m',
  domain: 'cognitive',
  durationMinutes: 15,
  durationEstimate: '10–15 mins',
  materials: ['none'],
  instructions: ['Sit together on a mat.', 'Stack two sturdy cups slowly.'],
  provenanceSource: 'Philippine ECCD Council NELF',
  status: Activity.statusSourceChecked,
  limitations: 'Everyday play idea only — not a medical or developmental test.',
);

void main() {
  test('normalizeActivityMaterials and displayActivityMaterials normalize empty placeholders', () {
    expect(normalizeActivityMaterials(['none', ' N/A ', 'wooden spoon']), [
      'wooden spoon',
    ]);
    expect(displayActivityMaterials(['none']), ['No materials needed']);
    expect(displayActivityMaterials(['cups']), ['cups']);
  });

  test(
    'AiService.adaptActivity posts to /api/v1/ai/adapt and parses response',
    () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'adapted': {
              'activityId': 'act-stack-cups',
              'originalTitle': 'Stack the cups',
              'adaptedTitle': 'Quick 5-min cup stack',
              'adjustment': 'shorter',
              'durationMinutes': 5,
              'instructions': [
                'Stack two cups together.',
                'Clap when they fall.',
              ],
              'materials': ['plastic cups'],
              'safetyNotice': 'Stay close during play.',
              'explanation': 'Keeps attention steady for a quick routine.',
            },
            'source': 'ai',
            'tier': 1,
            'provenance': {
              'badge': 'Suggested by AI',
              'disclaimer': 'Everyday play idea only.',
              'model': 'gemini-3.5-flash-lite',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: mockHttp,
        tokenProvider: () => 'test-token',
      );
      final service = AiService(apiClient: client);

      final res = await service.adaptActivity(
        activityId: 'act-stack-cups',
        adjustment: ActivityAdjustments.shorter,
        ageBand: '12-23m',
      );

      expect(capturedUri.path, '/api/v1/ai/adapt');
      expect(capturedBody['activityId'], 'act-stack-cups');
      expect(capturedBody['adjustment'], 'shorter');
      expect(res.isAiGenerated, isTrue);
      expect(res.adapted.adaptedTitle, 'Quick 5-min cup stack');
      expect(res.adapted.toActivity(_sampleActivity()).durationMinutes, 5);
    },
  );

  testWidgets(
    'ActivityDetailScreen normalizes none materials and expands adaptation on demand',
    (tester) async {
      Activity? scheduled;

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'adapted': {
              'activityId': 'act-stack-cups',
              'originalTitle': 'Stack the cups',
              'adaptedTitle': 'Quick 5-min cup stack',
              'adjustment': 'shorter',
              'durationMinutes': 5,
              'instructions': ['Stack two cups together.'],
              'materials': ['plastic cups'],
              'safetyNotice': 'Stay close during play.',
              'explanation': 'Fits a short 5-minute break.',
            },
            'source': 'ai',
            'tier': 1,
            'provenance': {
              'badge': 'Suggested by AI',
              'disclaimer': 'Everyday play idea only.',
              'model': 'gemini-3.5-flash-lite',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final aiService = AiService(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          httpClient: mockHttp,
          tokenProvider: () => 'test-token',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ActivityDetailScreen(
            activity: _sampleActivity(),
            aiService: aiService,
            onAddToPlan: (activity) async {
              scheduled = activity;
            },
          ),
        ),
      );

      expect(find.text('No materials needed'), findsOneWidget);
      expect(find.text('none'), findsNothing);

      await tester.tap(find.text('Adapt activity'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adjust activity'));
      await tester.pumpAndSettle();

      expect(find.text('Quick 5-min cup stack'), findsOneWidget);
      expect(find.text('Suggested by AI'), findsOneWidget);

      await tester.ensureVisible(find.text('Add adapted activity to plan'));
      await tester.tap(find.text('Add adapted activity to plan'));
      await tester.pumpAndSettle();

      expect(scheduled, isNotNull);
      expect(scheduled!.title, 'Quick 5-min cup stack');
      expect(scheduled!.id, 'custom-adapt-act-stack-cups');
    },
  );

  testWidgets(
    'ActivityDetailScreen starts with adaptation controls expanded when startInAdaptMode is true',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ActivityDetailScreen(
            activity: _sampleActivity(),
            startInAdaptMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Adapt this activity'), findsOneWidget);
      expect(find.text('Shorter (5–10 min)'), findsOneWidget);
      expect(find.text('Adjust activity'), findsOneWidget);
      expect(find.text('Adapt activity'), findsNothing);
    },
  );
}
