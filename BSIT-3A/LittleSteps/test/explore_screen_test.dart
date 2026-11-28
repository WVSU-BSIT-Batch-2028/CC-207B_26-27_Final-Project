import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:littlesteps/models/activity.dart';
import 'package:littlesteps/screens/explore/explore_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/services/local_cache.dart';
import 'package:littlesteps/services/plan_service.dart';
import 'package:littlesteps/theme/app_theme.dart';

void main() {
  testWidgets('shows activity source and pending review status', (
    tester,
  ) async {
    final catalog = _FakeCatalogService([_activity()]);
    await _pumpExplore(tester, catalog);

    expect(find.text('Cup tower'), findsOneWidget);
    expect(find.text('clean cups'), findsOneWidget);
    expect(find.text('Source: Synthetic fixture'), findsOneWidget);
    expect(find.text('Educational play reference'), findsOneWidget);
    expect(find.text("Add to today's plan"), findsOneWidget);
  });

  testWidgets('materials search filters the loaded activities immediately', (
    tester,
  ) async {
    final catalog = _FakeCatalogService([
      _activity(),
      _activity(
        id: 'act-rhyme',
        title: 'Clap together',
        materials: const ['none'],
      ),
    ]);
    await _pumpExplore(tester, catalog);

    await tester.enterText(
      find.byKey(const ValueKey('materials-search')),
      'cups',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cup tower'), findsOneWidget);
    expect(find.text('Clap together'), findsNothing);
  });

  testWidgets('clear filters resets search input and shows Idea Helper card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = _FakeCatalogService([_activity()]);
    await _pumpExplore(tester, catalog);

    await tester.enterText(
      find.byKey(const ValueKey('materials-search')),
      'nonexistent',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No activities found matching your filters'),
      findsOneWidget,
    );
    expect(find.text('Need a play idea?'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('materials-search')),
    );
    expect(searchField.controller?.text, isEmpty);
    expect(find.text('Cup tower'), findsOneWidget);
  });

  testWidgets('domain filter reloads the catalog immediately', (tester) async {
    final catalog = _FakeCatalogService([_activity()]);
    await _pumpExplore(tester, catalog);

    await tester.tap(find.byKey(const ValueKey('domain-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('domain-language')));
    await tester.pumpAndSettle();

    expect(catalog.lastDomain, 'language');
  });

  testWidgets('shows service unavailable with a retry action', (tester) async {
    final catalog = _FakeCatalogService([], failure: _serviceUnavailable());
    await _pumpExplore(tester, catalog);

    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows an offline notice on a network failure', (tester) async {
    final catalog = _FakeCatalogService(
      [],
      failure: const SocketException('offline'),
    );
    await _pumpExplore(tester, catalog);

    expect(
      find.text('You are offline. Reconnect to load activities.'),
      findsOneWidget,
    );
    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });

  testWidgets('shows cached activities with an offline notice', (tester) async {
    final cache = LocalDataCache();
    cache.set('/api/v1/catalog/activities?limit=50', {
      'items': [_activity().toJson()],
    });
    final apiClient = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient(
        (_) async => throw const SocketException('offline'),
      ),
      cache: cache,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ExploreScreen(
            catalogService: CatalogService(apiClient: apiClient),
            planService: PlanService(apiClient: apiClient),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You are offline. Reconnect to load activities.'),
      findsOneWidget,
    );
    expect(find.text('Cup tower'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('opens the more filters sheet without motion when reduced', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpExplore(
      tester,
      _FakeCatalogService([]),
      disableAnimations: true,
      observer: observer,
    );

    await tester.tap(find.byKey(const ValueKey('more-filters')));

    expect(observer.lastPushed?.transitionDuration, Duration.zero);
    expect(observer.lastPushed?.reverseTransitionDuration, Duration.zero);
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text("Child's age"), findsWidgets);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets(
    'citation sheet shows non-diagnostic copy, dynamic framework title, and website CTA',
    (tester) async {
      final eccdActivity = const Activity(
        id: 'act-eccd-nelf',
        title: 'Stack the Plastic Cups',
        type: 'activity',
        language: 'en',
        domain: 'cognitive',
        ageBand: '12-23m',
        durationMinutes: 10,
        durationEstimate: '10 mins',
        setting: 'indoor',
        materials: ['plastic cups'],
        instructions: ['Stack plastic cups together.'],
        limitations: 'Supervise closely.',
        status: 'reviewed_approved',
        provenanceSource: 'ECCD Council NELF (2010), Annex 4, p. 78',
      );
      await _pumpExplore(tester, _FakeCatalogService([eccdActivity]));

      await tester.ensureVisible(find.textContaining('ECCD Council NELF'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ECCD Council NELF'));
      await tester.pumpAndSettle();

      expect(find.text('Where this activity comes from'), findsOneWidget);
      expect(
        find.text('Philippine National Early Learning Framework (NELF)'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Adapted from published early childhood play and learning guidelines.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('clinical'), findsNothing);
      expect(find.text('Visit ECCD Council website'), findsOneWidget);
      expect(find.text('eccdcouncil.gov.ph'), findsOneWidget);
    },
  );

  testWidgets(
    'citation sheet omits external portal button for unmapped sources',
    (tester) async {
      final genericActivity = const Activity(
        id: 'act-generic',
        title: 'Water Pouring',
        type: 'activity',
        language: 'en',
        domain: 'motor',
        ageBand: '12-23m',
        durationMinutes: 10,
        durationEstimate: '10 mins',
        setting: 'indoor',
        materials: ['cups'],
        instructions: ['Pour water between cups.'],
        limitations: 'Supervise around water.',
        status: 'reviewed_approved',
        provenanceSource: 'Community Early Play Handbook (2024)',
      );
      await _pumpExplore(tester, _FakeCatalogService([genericActivity]));

      await tester.ensureVisible(
        find.textContaining('Community Early Play Handbook'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Community Early Play Handbook'));
      await tester.pumpAndSettle();

      expect(find.text('Where this activity comes from'), findsOneWidget);
      expect(find.text('Published early childhood guide'), findsOneWidget);
      expect(find.text('Visit ECCD Council website'), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    },
  );
}

Future<void> _pumpExplore(
  WidgetTester tester,
  _FakeCatalogService catalog, {
  bool disableAnimations = false,
  _RecordingNavigatorObserver? observer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      navigatorObservers: [?observer],
      home: Builder(
        builder: (context) {
          final screen = Scaffold(
            body: ExploreScreen(
              catalogService: catalog,
              planService: PlanService(
                apiClient: ApiClient(baseUrl: 'http://test'),
              ),
            ),
          );
          if (!disableAnimations) return screen;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: screen,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ApiException _serviceUnavailable() => ApiException(
  statusCode: 503,
  code: 'SERVICE_UNAVAILABLE',
  message: 'Please try again in a moment.',
);

Activity _activity({
  String id = 'act-cup-tower',
  String title = 'Cup tower',
  List<String> materials = const ['clean cups'],
}) => Activity(
  id: id,
  title: title,
  type: 'activity',
  language: 'en',
  domain: 'cognitive',
  ageBand: '12-23m',
  durationMinutes: 5,
  durationEstimate: '5 minutes',
  setting: 'indoor',
  materials: materials,
  instructions: const ['Stack clean cups together.'],
  limitations: 'Educational prompt only.',
  status: 'synthetic_fixture',
  provenanceSource: 'Synthetic fixture',
);

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this.activities, {this.failure})
    : super(apiClient: ApiClient(baseUrl: 'http://test'));

  final List<Activity> activities;
  final Object? failure;
  String? lastDomain;

  @override
  Future<List<Activity>> getActivities({
    String? ageBand,
    String? domain,
    String? language,
    String? setting,
    int limit = 50,
  }) async {
    lastDomain = domain;
    if (failure != null) throw failure!;
    return activities
        .where((activity) => ageBand == null || activity.ageBand == ageBand)
        .where((activity) => domain == null || activity.domain == domain)
        .where((activity) => language == null || activity.language == language)
        .toList();
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  ModalRoute<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route is ModalRoute<dynamic> ? route : null;
    super.didPush(route, previousRoute);
  }
}
