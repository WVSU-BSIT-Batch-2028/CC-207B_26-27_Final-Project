import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/activity.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/models/plan.dart';
import 'package:littlesteps/models/weather.dart';
import 'package:littlesteps/routing/app_router.dart';
import 'package:littlesteps/screens/today/today_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/services/plan_service.dart';

// Test activity fixture under 10 minutes with no materials needed and indoor setting.
const testActivityShortIndoor = Activity(
  id: 'act-1',
  title: 'Finger puppets song',
  type: 'activity',
  language: 'en',
  domain: 'language',
  ageBand: '12-23m',
  durationMinutes: 6,
  durationEstimate: 'Under 10 mins',
  setting: 'indoor',
  materials: [],
  instructions: ['Sing and move fingers.'],
  limitations: 'None',
  status: 'synthetic_fixture',
  provenanceSource: 'LittleSteps',
);

// Test activity fixture requiring materials and exceeding 10 minutes.
const testActivityLongWithMaterials = Activity(
  id: 'act-2',
  title: 'Building block tower',
  type: 'activity',
  language: 'en',
  domain: 'motor',
  ageBand: '12-23m',
  durationMinutes: 18,
  durationEstimate: '15-30 mins',
  setting: 'indoor',
  materials: ['wooden blocks'],
  instructions: ['Stack three blocks high.'],
  limitations: 'Supervise with small parts.',
  status: 'synthetic_fixture',
  provenanceSource: 'LittleSteps',
);

// Test activity fixture set outdoors.
const testActivityOutdoor = Activity(
  id: 'act-3',
  title: 'Leaves and breeze walk',
  type: 'activity',
  language: 'en',
  domain: 'cognitive',
  ageBand: '12-23m',
  durationMinutes: 20,
  durationEstimate: '15-30 mins',
  setting: 'outdoor',
  materials: [],
  instructions: ['Walk outside and watch leaves flutter.'],
  limitations: 'Watch footpaths.',
  status: 'synthetic_fixture',
  provenanceSource: 'LittleSteps',
);

// Helper creating a PlanItem for testing.
PlanItem createTestPlan({
  required String id,
  required String activityId,
  String status = 'planned',
}) {
  return PlanItem(
    id: id,
    childId: 'child-123',
    activityId: activityId,
    scheduledDate: '2026-11-23',
    status: status,
    createdAt: DateTime(2026, 11, 23),
    updatedAt: DateTime(2026, 11, 23),
  );
}

// Helper creating a Child profile for testing.
Child createTestChild({String id = 'child-123', String nickname = 'Maya'}) {
  return Child(
    id: id,
    nickname: nickname,
    ageBand: '12-23m',
    birthMonthYear: '2025-05',
    createdAt: DateTime(2025, 5, 1),
    updatedAt: DateTime(2025, 5, 1),
  );
}

// Wraps a widget under test with a standard MaterialApp and optional text scaling.
Widget buildTestApp(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    home: textScaler != null
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child,
            ),
          )
        : child,
  );
}

void main() {
  setUp(() {
    TodayAdvisoryStorage.reset();
  });

  group('TodayScreen State & View Tests', () {
    testWidgets('renders loading view when loading state is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const TodayScreen(initialState: TodayViewState.loading)),
      );

      expect(find.text("Loading today's plan..."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'renders empty state when no activities are planned for today',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const TodayScreen(
              initialState: TodayViewState.empty,
              initialPlans: [],
            ),
          ),
        );

        expect(find.text('No activities planned for today'), findsOneWidget);
        expect(find.byIcon(Icons.today_outlined), findsOneWidget);
      },
    );

    testWidgets('renders offline banner when in offline state', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const TodayScreen(
            initialState: TodayViewState.offline,
            isOffline: true,
          ),
        ),
      );

      expect(
        find.text('Working offline. Changes will sync when reconnected.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'handles NOT_FOUND error code with clear message and retry action',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'RESOURCE_NOT_FOUND',
                'message': 'Activity not found in catalog',
              },
            }),
            404,
          );
        });

        final apiClient = ApiClient(
          baseUrl: 'http://test',
          httpClient: mockClient,
        );
        final planService = PlanService(apiClient: apiClient);
        final catalogService = CatalogService(apiClient: apiClient);

        await tester.pumpWidget(
          buildTestApp(
            TodayScreen(
              planService: planService,
              catalogService: catalogService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text(
            "This activity isn't available anymore. It was taken off our list. The rest of your plan is still here.",
          ),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
      },
    );
  });

  group('TodayScreen Quick Filters Tests', () {
    final samplePlans = [
      createTestPlan(id: 'p1', activityId: testActivityShortIndoor.id),
      createTestPlan(id: 'p2', activityId: testActivityLongWithMaterials.id),
      createTestPlan(id: 'p3', activityId: testActivityOutdoor.id),
    ];

    final sampleLookup = {
      testActivityShortIndoor.id: testActivityShortIndoor,
      testActivityLongWithMaterials.id: testActivityLongWithMaterials,
      testActivityOutdoor.id: testActivityOutdoor,
    };

    testWidgets('filters activities by "Under 10 mins"', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: samplePlans,
            initialActivities: sampleLookup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finger puppets song'), findsOneWidget);
      expect(find.text('Building block tower'), findsOneWidget);
      expect(find.text('Leaves and breeze walk'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Under 10 mins'));
      await tester.pumpAndSettle();

      expect(find.text('Finger puppets song'), findsOneWidget);
      expect(find.text('Building block tower'), findsNothing);
      expect(find.text('Leaves and breeze walk'), findsNothing);
    });

    testWidgets('filters activities by "No materials needed"', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: samplePlans,
            initialActivities: sampleLookup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'No materials needed'));
      await tester.pumpAndSettle();

      expect(find.text('Finger puppets song'), findsOneWidget);
      expect(find.text('Building block tower'), findsNothing);
      expect(find.text('Leaves and breeze walk'), findsOneWidget);
    });

    testWidgets('filters activities by "Indoor"', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: samplePlans,
            initialActivities: sampleLookup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Indoor'));
      await tester.pumpAndSettle();

      expect(find.text('Finger puppets song'), findsOneWidget);
      expect(find.text('Building block tower'), findsOneWidget);
      expect(find.text('Leaves and breeze walk'), findsNothing);
    });

    testWidgets(
      'combines filters and shows empty filter state with clear action',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            TodayScreen(
              initialState: TodayViewState.ready,
              initialPlans: [
                createTestPlan(id: 'p3', activityId: testActivityOutdoor.id),
              ],
              initialActivities: sampleLookup,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilterChip, 'Indoor'));
        await tester.pumpAndSettle();

        expect(find.text('No activities match your filters'), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);

        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();

        expect(find.text('Leaves and breeze walk'), findsOneWidget);
      },
    );
  });

  group('TodayScreen Activity Completion, Badge & Undo Tests', () {
    testWidgets(
      'completion updates status and displays factual "Completed today" badge',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final patchCalls = <String>[];
        final mockClient = MockClient((request) async {
          if (request.method == 'PATCH') {
            patchCalls.add(request.url.path);
            return http.Response(
              jsonEncode({
                'id': 'p1',
                'childId': 'child-123',
                'activityId': testActivityShortIndoor.id,
                'scheduledDate': '2026-11-23',
                'status': 'completed',
                'createdAt': '2026-11-23T00:00:00.000Z',
                'updatedAt': '2026-11-23T00:00:00.000Z',
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        });

        final planService = PlanService(
          apiClient: ApiClient(baseUrl: 'http://test', httpClient: mockClient),
        );

        final initialPlan = createTestPlan(
          id: 'p1',
          activityId: testActivityShortIndoor.id,
          status: 'planned',
        );

        await tester.pumpWidget(
          buildTestApp(
            TodayScreen(
              initialState: TodayViewState.ready,
              initialPlans: [initialPlan],
              initialActivities: {
                testActivityShortIndoor.id: testActivityShortIndoor,
              },
              planService: planService,
              activeChild: createTestChild(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mark complete'), findsOneWidget);
        expect(find.text('Completed today'), findsNothing);

        await tester.tap(find.text('Mark complete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Completed today'), findsOneWidget);
        expect(patchCalls, contains('/api/v1/children/child-123/plans/p1'));

        expect(
          find.textContaining(RegExp('streak', caseSensitive: false)),
          findsNothing,
        );
        expect(
          find.textContaining(RegExp('score', caseSensitive: false)),
          findsNothing,
        );
        expect(
          find.textContaining(RegExp('points', caseSensitive: false)),
          findsNothing,
        );
        expect(
          find.textContaining(RegExp('praise', caseSensitive: false)),
          findsNothing,
        );

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        final SnackBar snackBar = tester.widget(snackBarFinder);
        expect(snackBar.duration.inSeconds, greaterThanOrEqualTo(10));
        expect(find.text('Undo'), findsOneWidget);
      },
    );

    testWidgets('tapping undo reverses completion via API', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final patchCalls = <Map<String, dynamic>>[];
      final mockClient = MockClient((request) async {
        if (request.method == 'PATCH') {
          patchCalls.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'id': 'p1',
              'childId': 'child-123',
              'activityId': testActivityShortIndoor.id,
              'scheduledDate': '2026-11-23',
              'status': 'planned',
              'createdAt': '2026-11-23T00:00:00.000Z',
              'updatedAt': '2026-11-23T00:00:00.000Z',
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final planService = PlanService(
        apiClient: ApiClient(baseUrl: 'http://test', httpClient: mockClient),
      );

      final initialPlan = createTestPlan(
        id: 'p1',
        activityId: testActivityShortIndoor.id,
        status: 'planned',
      );

      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: [initialPlan],
            initialActivities: {
              testActivityShortIndoor.id: testActivityShortIndoor,
            },
            planService: planService,
            activeChild: createTestChild(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark complete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mark complete'), findsOneWidget);
      expect(find.text('Completed today'), findsNothing);
      expect(patchCalls.last['status'], 'planned');
    });

    testWidgets('offline completion shows warning and does not mark as saved', (
      tester,
    ) async {
      final initialPlan = createTestPlan(
        id: 'p1',
        activityId: testActivityShortIndoor.id,
        status: 'planned',
      );

      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: [initialPlan],
            initialActivities: {
              testActivityShortIndoor.id: testActivityShortIndoor,
            },
            isOffline: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark complete'));
      await tester.pump();

      expect(find.text("This activity wasn't marked complete"), findsOneWidget);
      expect(find.text('Completed today'), findsNothing);
      expect(find.text('Mark complete'), findsOneWidget);
    });
  });

  group('TodayScreen Non-Diagnostic Advisory Tests', () {
    testWidgets(
      'shows full advisory on first visit and persistent link after dismissal',
      (tester) async {
        final initialPlan = createTestPlan(
          id: 'p1',
          activityId: testActivityShortIndoor.id,
        );

        await tester.pumpWidget(
          buildTestApp(
            TodayScreen(
              initialState: TodayViewState.ready,
              initialPlans: [initialPlan],
              initialActivities: {
                testActivityShortIndoor.id: testActivityShortIndoor,
              },
              activeChild: createTestChild(id: 'child-advisory-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Not a diagnostic tool. Observational play suggestions only. You know your child best.',
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('Dismiss advisory'), findsOneWidget);

        await tester.tap(find.byTooltip('Dismiss advisory'));
        await tester.pumpAndSettle();

        expect(find.text('Not a diagnostic tool'), findsOneWidget);
        expect(find.byTooltip('Dismiss advisory'), findsNothing);

        await tester.tap(find.text('Not a diagnostic tool'));
        await tester.pumpAndSettle();

        expect(find.text('Close'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('TodayScreen Weather Hint Guidance Tests', () {
    testWidgets(
      'shows dismissible weather hint with Open-Meteo attribution and indoor play-idea action',
      (tester) async {
        String? requestedSetting;
        const weather = WeatherHint(
          condition: 'rain',
          rainChance: 85,
          heatFlag: false,
          suggestedSetting: 'indoor',
          hint: 'Rain likely this afternoon · Indoor ideas',
          attribution: 'Weather data by Open-Meteo.com',
        );

        await tester.pumpWidget(
          buildTestApp(
            TodayScreen(
              initialState: TodayViewState.ready,
              initialPlans: [
                createTestPlan(
                  id: 'p1',
                  activityId: testActivityShortIndoor.id,
                ),
                createTestPlan(id: 'p3', activityId: testActivityOutdoor.id),
              ],
              initialActivities: {
                testActivityShortIndoor.id: testActivityShortIndoor,
                testActivityOutdoor.id: testActivityOutdoor,
              },
              initialWeatherHint: weather,
              onOpenIdeaHelper: (setting) => requestedSetting = setting,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rain likely this afternoon'), findsOneWidget);
        expect(find.text('Weather data by Open-Meteo.com'), findsOneWidget);
        expect(find.text('Find indoor ideas'), findsOneWidget);

        await tester.tap(find.text('Find indoor ideas'));
        await tester.pumpAndSettle();

        expect(requestedSetting, 'indoor');

        await tester.tap(find.byTooltip('Dismiss weather hint'));
        await tester.pumpAndSettle();

        expect(find.text('Rain likely this afternoon'), findsNothing);
      },
    );

    testWidgets(
      'navigates to Idea Helper with Outdoor preselected when outdoor CTA is tapped',
      (tester) async {
        const weather = WeatherHint(
          condition: 'clear',
          rainChance: 5,
          heatFlag: false,
          suggestedSetting: 'outdoor',
          hint: 'Good weather for outdoor play · Outdoor ideas',
          attribution: 'Weather data by Open-Meteo.com',
        );

        await tester.pumpWidget(
          const MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: TodayScreen(
              initialState: TodayViewState.empty,
              initialPlans: [],
              initialWeatherHint: weather,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Good weather for outdoor play'), findsOneWidget);
        expect(find.text('Find outdoor ideas'), findsOneWidget);

        await tester.tap(find.text('Find outdoor ideas'));
        await tester.pumpAndSettle();

        expect(find.text('Idea helper'), findsWidgets);
        final outdoorChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Outdoor'),
        );
        expect(outdoorChip.selected, isTrue);
      },
    );

    testWidgets(
      'navigates to Idea Helper with Indoor preselected when indoor CTA is tapped',
      (tester) async {
        const weather = WeatherHint(
          condition: 'rain',
          rainChance: 80,
          heatFlag: false,
          suggestedSetting: 'indoor',
          hint: 'Rain likely this afternoon · Indoor ideas',
          attribution: 'Weather data by Open-Meteo.com',
        );

        await tester.pumpWidget(
          const MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: TodayScreen(
              initialState: TodayViewState.empty,
              initialPlans: [],
              initialWeatherHint: weather,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rain likely this afternoon'), findsOneWidget);
        expect(find.text('Find indoor ideas'), findsOneWidget);

        await tester.tap(find.text('Find indoor ideas'));
        await tester.pumpAndSettle();

        expect(find.text('Idea helper'), findsWidgets);
        final indoorChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Indoor'),
        );
        expect(indoorChip.selected, isTrue);
      },
    );

    testWidgets(
      'navigates to Idea Helper with Indoor or outdoor preselected when either CTA is tapped',
      (tester) async {
        const weather = WeatherHint(
          condition: 'cloudy',
          rainChance: 15,
          heatFlag: false,
          suggestedSetting: 'either',
          hint: 'Mild weather today',
          attribution: 'Weather data by Open-Meteo.com',
        );

        await tester.pumpWidget(
          const MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: TodayScreen(
              initialState: TodayViewState.empty,
              initialPlans: [],
              initialWeatherHint: weather,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mild weather today'), findsOneWidget);
        expect(find.text('Find play ideas'), findsOneWidget);

        await tester.tap(find.text('Find play ideas'));
        await tester.pumpAndSettle();

        expect(find.text('Idea helper'), findsWidgets);
        final eitherChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Indoor or outdoor'),
        );
        expect(eitherChip.selected, isTrue);
      },
    );

    testWidgets('renders nothing when weather hint is null or unavailable', (
      tester,
    ) async {
      const weather = WeatherHint(
        condition: 'unavailable',
        rainChance: 0,
        heatFlag: false,
        suggestedSetting: 'either',
        hint: null,
        attribution: 'Weather data by Open-Meteo.com',
      );

      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: [
              createTestPlan(id: 'p1', activityId: testActivityShortIndoor.id),
            ],
            initialActivities: {
              testActivityShortIndoor.id: testActivityShortIndoor,
            },
            initialWeatherHint: weather,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);
      expect(find.text('Weather data by Open-Meteo.com'), findsNothing);
    });
  });

  group('TodayScreen Accessibility & 200% Text Scale Tests', () {
    testWidgets('renders cleanly without overflow at 200% text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final plans = [
        createTestPlan(id: 'p1', activityId: testActivityShortIndoor.id),
        createTestPlan(id: 'p2', activityId: testActivityLongWithMaterials.id),
      ];

      final activities = {
        testActivityShortIndoor.id: testActivityShortIndoor,
        testActivityLongWithMaterials.id: testActivityLongWithMaterials,
      };

      const weather = WeatherHint(
        condition: 'cloudy',
        rainChance: 20,
        heatFlag: false,
        suggestedSetting: 'either',
        hint: 'Cloudy morning · Good for indoor or outdoor play',
        attribution: 'Weather data by Open-Meteo.com',
      );

      await tester.pumpWidget(
        buildTestApp(
          TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: plans,
            initialActivities: activities,
            initialWeatherHint: weather,
          ),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finger puppets song'), findsOneWidget);
      expect(find.text('Building block tower'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'formats tag badges cleanly for domain, setting, and material counts',
      (tester) async {
        const socioEitherActivity = Activity(
          id: 'act-socio',
          title: 'Emotion faces in mirror',
          type: 'activity',
          language: 'en',
          domain: 'socioEmotional',
          ageBand: '12-23m',
          durationMinutes: 10,
          durationEstimate: '10 mins',
          setting: 'either',
          materials: ['small mirror'],
          instructions: ['Make faces in mirror.'],
          limitations: 'Supervise with glass.',
          status: 'synthetic_fixture',
          provenanceSource: 'LittleSteps',
        );

        final plan = createTestPlan(
          id: 'p-socio',
          activityId: socioEitherActivity.id,
        );
        final lookup = {socioEitherActivity.id: socioEitherActivity};

        await tester.pumpWidget(
          buildTestApp(
            TodayScreen(
              initialState: TodayViewState.ready,
              initialPlans: [plan],
              initialActivities: lookup,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Socio-emotional'), findsOneWidget);
        expect(find.text('Indoor or outdoor'), findsOneWidget);
        expect(find.text('1 material'), findsOneWidget);
      },
    );

    testWidgets(
      'switching active child reloads plans and resets quick filters',
      (tester) async {
        final childMaya = createTestChild(id: 'child-maya', nickname: 'Maya');
        final childLeo = createTestChild(id: 'child-leo', nickname: 'Leo');

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/plans')) {
            if (request.url.path.contains('child-maya')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'p-maya',
                    'childId': 'child-maya',
                    'activityId': testActivityShortIndoor.id,
                    'scheduledDate': '2026-11-24',
                    'status': 'planned',
                    'createdAt': '2026-11-24T00:00:00.000Z',
                    'updatedAt': '2026-11-24T00:00:00.000Z',
                  },
                ]),
                200,
              );
            } else if (request.url.path.contains('child-leo')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'p-leo',
                    'childId': 'child-leo',
                    'activityId': testActivityOutdoor.id,
                    'scheduledDate': '2026-11-24',
                    'status': 'planned',
                    'createdAt': '2026-11-24T00:00:00.000Z',
                    'updatedAt': '2026-11-24T00:00:00.000Z',
                  },
                ]),
                200,
              );
            }
            return http.Response(jsonEncode([]), 200);
          }
          if (request.url.path.contains('/catalog/activities/')) {
            final id = request.url.pathSegments.last;
            if (id == testActivityShortIndoor.id) {
              return http.Response(
                jsonEncode(testActivityShortIndoor.toJson()),
                200,
              );
            }
            if (id == testActivityOutdoor.id) {
              return http.Response(
                jsonEncode(testActivityOutdoor.toJson()),
                200,
              );
            }
          }
          if (request.url.path.contains('/catalog/activities')) {
            return http.Response(
              jsonEncode({
                'items': [
                  testActivityShortIndoor.toJson(),
                  testActivityOutdoor.toJson(),
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({}), 200);
        });

        final apiClient = ApiClient(
          baseUrl: 'http://test',
          httpClient: mockClient,
        );
        final planService = PlanService(apiClient: apiClient);
        final catalogService = CatalogService(apiClient: apiClient);

        Widget buildScreen(Child child) {
          return buildTestApp(
            TodayScreen(
              planService: planService,
              catalogService: catalogService,
              activeChild: child,
            ),
          );
        }

        await tester.pumpWidget(buildScreen(childMaya));
        await tester.pumpAndSettle();

        expect(find.text('Finger puppets song'), findsOneWidget);
        expect(find.text('Leaves and breeze walk'), findsNothing);

        // Tap Under 10 mins quick filter
        await tester.tap(find.text('Under 10 mins'));
        await tester.pumpAndSettle();

        // Switch active child to Leo
        await tester.pumpWidget(buildScreen(childLeo));
        await tester.pumpAndSettle();

        expect(find.text('Leaves and breeze walk'), findsOneWidget);
        expect(find.text('Finger puppets song'), findsNothing);
      },
    );
  });
}
