import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/explore/widgets/explore_filter_controls.dart';
import 'package:littlesteps/screens/today/today_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/catalog_service.dart';
import 'package:littlesteps/services/plan_service.dart';
import 'package:littlesteps/theme/app_theme.dart';
import 'package:littlesteps/utils/domain_labels.dart';

void main() {
  group('HorizontalScrollFade scroll persistence', () {
    testWidgets(
      'preserves scroll position when scrolling SingleChildScrollView to the right end',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: 56,
                child: HorizontalScrollFade(
                  child: SingleChildScrollView(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        8,
                        (index) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(width: 90, child: Text('Tab $index')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.position.maxScrollExtent, greaterThan(100));
        expect(controller.offset, 0);

        // Drag all the way to the right end so extentAfter drops below 4dp.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-800, 0),
        );
        await tester.pumpAndSettle();

        expect(
          controller.offset,
          closeTo(controller.position.maxScrollExtent, 1.0),
        );
        expect(controller.offset, greaterThan(100));
      },
    );

    testWidgets(
      'preserves ExploreDomainFilters scroll position when scrolled to end and tapped',
      (tester) async {
        String? selectedDomain;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SizedBox(
                  width: 260,
                  child: ExploreDomainFilters(
                    domains: AppDomains.labels,
                    selectedDomain: selectedDomain,
                    onSelected: (domain) =>
                        setState(() => selectedDomain = domain),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final listFinder = find.byKey(const ValueKey('domain-filters'));
        await tester.drag(listFinder, const Offset(-400, 0));
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: listFinder, matching: find.byType(Scrollable)),
        );
        final offsetAtEnd = scrollable.position.pixels;
        expect(offsetAtEnd, greaterThan(0));

        await tester.tap(find.text('Feelings'));
        await tester.pumpAndSettle();

        expect(selectedDomain, AppDomains.socioEmotional);
        expect(scrollable.position.pixels, closeTo(offsetAtEnd, 1.0));
      },
    );
  });

  group('TodayScreen live milestone cues', () {
    testWidgets(
      'loads milestone cues from CatalogService instead of hardcoded text',
      (tester) async {
        String? requestedAgeBand;
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/plans')) {
            return http.Response(jsonEncode(<dynamic>[]), 200);
          }
          if (request.url.path.endsWith('/catalog/weather')) {
            return http.Response(
              jsonEncode({
                'condition': 'unavailable',
                'rainChance': 0,
                'heatFlag': false,
                'suggestedSetting': 'either',
                'hint': null,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/catalog/milestones')) {
            requestedAgeBand = request.url.queryParameters['ageBand'];
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'lan-12-01',
                    'domain': 'language',
                    'title': 'Points to familiar objects when named',
                    'lookFor': ['Points at a ball when named'],
                    'ageBand': '12-23 months',
                    'provenance': 'Source: CDC Developmental Milestones',
                  },
                  {
                    'id': 'cog-12-01',
                    'domain': 'cognitive',
                    'title': 'Finds a hidden toy',
                    'lookFor': ['Uncovers a toy under a cloth'],
                    'ageBand': '12-23 months',
                    'provenance': 'Source: CDC Developmental Milestones',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        });

        final apiClient = ApiClient(
          baseUrl: 'http://test',
          httpClient: mockClient,
        );
        final child = Child(
          id: 'child-1',
          nickname: 'Maya',
          ageBand: '12-23m',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: TodayScreen(
              activeChild: child,
              planService: PlanService(apiClient: apiClient),
              catalogService: CatalogService(apiClient: apiClient),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(requestedAgeBand, '12-23 months');
        await tester.scrollUntilVisible(
          find.text('Points to familiar objects when named'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('Points to familiar objects when named'),
          findsOneWidget,
        );
        expect(find.text('Finds a hidden toy'), findsOneWidget);
      },
    );
  });
}
