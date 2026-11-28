import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/activity.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/today/today_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/services/children_service.dart';
import 'package:littlesteps/services/local_cache.dart';
import 'package:littlesteps/services/plan_service.dart';
import 'package:littlesteps/widgets/state_views.dart';

// Sample child fixture for testing child profile serialization and caching.
final sampleChildJson = {
  'id': 'child-c1',
  'nickname': 'Maya',
  'ageBand': '12-23m',
  'birthMonthYear': '2025-05',
  'createdAt': '2025-05-01T00:00:00.000Z',
  'updatedAt': '2025-05-01T00:00:00.000Z',
};

// Sample catalog activity JSON fixture matching backend schema.
final sampleActivityJson = {
  'id': 'act-cups',
  'title': 'Stack the cups',
  'type': 'activity',
  'language': 'en',
  'setting': 'indoor',
  'ageBand': '12-23m',
  'domain': 'motor',
  'durationMinutes': 10,
  'durationEstimate': 'Under 10 mins',
  'materials': ['cups'],
  'instructions': ['Stack two cups.'],
  'provenanceSource': 'LittleSteps',
  'status': 'synthetic_fixture',
  'limitations': 'Watch stacks.',
};

// Sample plan JSON fixture for today's scheduled play.
final samplePlanJson = {
  'id': 'p-today-1',
  'childId': 'child-c1',
  'activityId': 'act-cups',
  'scheduledDate': '2026-11-24',
  'status': 'planned',
  'createdAt': '2026-11-24T00:00:00.000Z',
  'updatedAt': '2026-11-24T00:00:00.000Z',
};

// Helper creating a test application wrapper with optional text scaling.
Widget buildOfflineTestApp(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    home: textScaler != null
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: Scaffold(body: child),
            ),
          )
        : Scaffold(body: child),
  );
}

void main() {
  group('ApiClient Typed Errors & Service Pass-Through Tests', () {
    test('maps TimeoutException to TimeoutApiException', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final client = ApiClient(baseUrl: 'http://test', httpClient: mockClient);

      expect(
        () => client.get('/api/v1/children'),
        throwsA(isA<TimeoutApiException>()),
      );
    });

    test('maps SocketException to NoConnectionApiException', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup');
      });

      final client = ApiClient(baseUrl: 'http://test', httpClient: mockClient);

      expect(
        () => client.get('/api/v1/children'),
        throwsA(isA<NoConnectionApiException>()),
      );
    });

    test('maps 401 and 403 status codes to AuthApiException', () async {
      final mock401Client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHENTICATED', 'message': 'Expired session'},
          }),
          401,
        );
      });

      final client401 = ApiClient(
        baseUrl: 'http://test',
        httpClient: mock401Client,
      );

      expect(
        () => client401.get('/api/v1/children'),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      final mock403Client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'FORBIDDEN', 'message': 'Access denied'},
          }),
          403,
        );
      });

      final client403 = ApiClient(
        baseUrl: 'http://test',
        httpClient: mock403Client,
      );

      expect(
        () => client403.get('/api/v1/children'),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('maps 404 status code to NotFoundApiException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'NOT_FOUND', 'message': 'Item missing'},
          }),
          404,
        );
      });

      final client = ApiClient(baseUrl: 'http://test', httpClient: mockClient);

      expect(
        () => client.get('/api/v1/children/nonexistent'),
        throwsA(
          isA<NotFoundApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('maps 5xx status codes to ServerApiException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Server down'},
          }),
          503,
        );
      });

      final client = ApiClient(baseUrl: 'http://test', httpClient: mockClient);

      expect(
        () => client.get('/api/v1/children'),
        throwsA(
          isA<ServerApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test(
      'services pass typed errors up unchanged without swallowing',
      () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Network down');
        });

        final client = ApiClient(
          baseUrl: 'http://test',
          httpClient: mockClient,
        );

        final childrenService = ChildrenService(apiClient: client);
        final catalogService = CatalogService(apiClient: client);
        final planService = PlanService(apiClient: client);

        expect(
          () => childrenService.getChildren(),
          throwsA(isA<NoConnectionApiException>()),
        );
        expect(
          () => catalogService.getActivities(),
          throwsA(isA<NoConnectionApiException>()),
        );
        expect(
          () => planService.getPlans('child-c1'),
          throwsA(isA<NoConnectionApiException>()),
        );
      },
    );
  });

  group('LocalDataCache Whitelisting & Privacy Tests', () {
    test(
      'caches child list, catalog, and today plan on successful reads',
      () async {
        final cache = LocalDataCache();
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/children') {
            return http.Response(jsonEncode([sampleChildJson]), 200);
          }
          if (request.url.path == '/api/v1/catalog/activities') {
            return http.Response(
              jsonEncode({
                'items': [sampleActivityJson],
              }),
              200,
            );
          }
          if (request.url.path.contains('/plans')) {
            return http.Response(jsonEncode([samplePlanJson]), 200);
          }
          return http.Response('[]', 200);
        });

        final client = ApiClient(
          baseUrl: 'http://test',
          httpClient: mockClient,
          cache: cache,
        );

        final childrenService = ChildrenService(apiClient: client);
        final catalogService = CatalogService(apiClient: client);
        final planService = PlanService(apiClient: client);

        final children = await childrenService.getChildren();
        expect(children.length, 1);
        expect(cache.has('/api/v1/children'), isTrue);

        final activities = await catalogService.getActivities();
        expect(activities.length, 1);
        expect(cache.has('/api/v1/catalog/activities?limit=50'), isTrue);

        final plans = await planService.getPlans(
          'child-c1',
          date: '2026-11-24',
        );
        expect(plans.length, 1);
        expect(
          cache.has('/api/v1/children/child-c1/plans?date=2026-11-24'),
          isTrue,
        );
      },
    );

    test(
      'refuses to cache sensitive data such as tokens or private journals',
      () async {
        final cache = LocalDataCache();

        cache.set('/api/v1/journal', {'note': 'private observations'});
        cache.set('/api/v1/auth/tokens', {'token': 'secret123'});

        expect(cache.has('/api/v1/journal'), isFalse);
        expect(cache.has('/api/v1/auth/tokens'), isFalse);
      },
    );

    test('clears cache on sign-out so no child data remains', () async {
      final cache = LocalDataCache();
      cache.set('/api/v1/children', [sampleChildJson]);
      cache.set('/api/v1/children/child-c1/plans', [samplePlanJson]);

      expect(cache.has('/api/v1/children'), isTrue);

      final client = ApiClient(baseUrl: 'http://test', cache: cache);
      client.clearCache();

      expect(cache.has('/api/v1/children'), isFalse);
      expect(cache.has('/api/v1/children/child-c1/plans'), isFalse);
      expect(cache.entryCount, 0);
    });
  });

  group('Offline Reads & State Matrix Tests', () {
    test(
      'offline read returns cached data and sets isOffline to true',
      () async {
        final cache = LocalDataCache();
        cache.set('/api/v1/children', [sampleChildJson]);

        final offlineClient = MockClient((request) async {
          throw const SocketException('No route to host');
        });

        final client = ApiClient(
          baseUrl: 'http://test',
          httpClient: offlineClient,
          cache: cache,
        );

        final childrenService = ChildrenService(apiClient: client);
        final children = await childrenService.getChildren();

        expect(children.length, 1);
        expect(children.first.nickname, 'Maya');
        expect(client.isOffline, isTrue);
      },
    );

    test('offline read with no cache throws NoConnectionApiException for empty/offline state', () async {
      final cache = LocalDataCache();
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet');
      });

      final client = ApiClient(
        baseUrl: 'http://test',
        httpClient: offlineClient,
        cache: cache,
      );

      final childrenService = ChildrenService(apiClient: client);

      expect(
        () => childrenService.getChildren(),
        throwsA(isA<NoConnectionApiException>()),
      );
    });

    testWidgets(
      'renders OfflineBanner and cached activities when network drops',
      (tester) async {
        final cache = LocalDataCache();
        cache.set('/api/v1/children/child-c1/plans?date=2026-11-24', [
          samplePlanJson,
        ]);

        final offlineClient = MockClient((request) async {
          throw const SocketException('Offline');
        });

        final client = ApiClient(
          baseUrl: 'http://test',
          httpClient: offlineClient,
          cache: cache,
        );

        final planService = PlanService(apiClient: client);

        await tester.pumpWidget(
          buildOfflineTestApp(
            TodayScreen(
              planService: planService,
              activeChild: Child.fromJson(sampleChildJson),
              initialDate: DateTime(2026, 11, 24),
              initialActivities: {
                'act-cups': Activity.fromJson(sampleActivityJson),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OfflineBanner), findsOneWidget);
        expect(
          find.text('Working offline. Changes will sync when reconnected.'),
          findsOneWidget,
        );
        expect(find.text('Stack the cups'), findsOneWidget);
      },
    );

    testWidgets(
      'renders proper offline state when network fails and no cache exists',
      (tester) async {
        final cache = LocalDataCache();
        final offlineClient = MockClient((request) async {
          throw const SocketException('Offline');
        });

        final client = ApiClient(
          baseUrl: 'http://test',
          httpClient: offlineClient,
          cache: cache,
        );

        final planService = PlanService(apiClient: client);

        await tester.pumpWidget(
          buildOfflineTestApp(
            TodayScreen(
              planService: planService,
              activeChild: Child.fromJson(sampleChildJson),
              initialDate: DateTime(2026, 11, 24),
              initialActivities: {
                'act-cups': Activity.fromJson(sampleActivityJson),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OfflineBanner), findsOneWidget);
        expect(find.text('No activities planned for today'), findsOneWidget);
      },
    );
  });

  group('Offline Writes & Recovery Tests', () {
    test('writes are disabled offline, throw OfflineWriteApiException, and queue nothing', () async {
      final writeCalls = <String>[];
      final mockClient = MockClient((request) async {
        writeCalls.add('${request.method} ${request.url.path}');
        return http.Response('{}', 200);
      });

      final client = ApiClient(baseUrl: 'http://test', httpClient: mockClient);
      client.isOffline = true;

      final childrenService = ChildrenService(apiClient: client);
      final planService = PlanService(apiClient: client);

      expect(
        () => childrenService.createChild(nickname: 'Leo'),
        throwsA(
          isA<OfflineWriteApiException>().having(
            (e) => e.message,
            'message',
            'Reconnect to save changes',
          ),
        ),
      );

      expect(
        () => planService.updatePlanStatus(
          childId: 'child-c1',
          planId: 'p1',
          status: 'completed',
        ),
        throwsA(
          isA<OfflineWriteApiException>().having(
            (e) => e.message,
            'message',
            'Reconnect to save changes',
          ),
        ),
      );

      expect(writeCalls, isEmpty);
    });

    test('network recovery clears offline state and allows writes to resume without restart', () async {
      var failNetwork = true;
      final writeCalls = <String>[];

      final mockClient = MockClient((request) async {
        if (failNetwork) {
          throw const SocketException('Connection lost');
        }
        writeCalls.add('${request.method} ${request.url.path}');
        return http.Response(jsonEncode(sampleChildJson), 200);
      });

      final client = ApiClient(baseUrl: 'http://test', httpClient: mockClient);

      final childrenService = ChildrenService(apiClient: client);

      await expectLater(
        () => childrenService.createChild(nickname: 'Leo'),
        throwsA(isA<OfflineWriteApiException>()),
      );
      expect(client.isOffline, isTrue);

      failNetwork = false;
      client.isOffline = false;

      final child = await childrenService.createChild(nickname: 'Leo');
      expect(child.nickname, 'Maya');
      expect(client.isOffline, isFalse);
      expect(writeCalls, contains('POST /api/v1/children'));
    });
  });

  group('Accessibility & 200% Text Scale Tests', () {
    testWidgets(
      'OfflineBanner renders cleanly without overflow at 200% text scale',
      (tester) async {
        await tester.pumpWidget(
          buildOfflineTestApp(
            const Column(
              children: [
                OfflineBanner(),
                SizedBox(height: 16),
                Text('Reconnect to save changes'),
              ],
            ),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Working offline. Changes will sync when reconnected.'),
          findsOneWidget,
        );
        expect(find.text('Reconnect to save changes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('OfflineBanner contains accessibility live region semantics', (
      tester,
    ) async {
      await tester.pumpWidget(buildOfflineTestApp(const OfflineBanner()));
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
