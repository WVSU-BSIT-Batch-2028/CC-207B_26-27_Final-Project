import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/plan_service.dart';

const _plan = {
  'id': 'p1',
  'childId': 'c1',
  'activityId': 'a1',
  'scheduledDate': '2026-11-18',
  'status': 'planned',
  'createdAt': '2026-11-18T00:00:00.000Z',
  'updatedAt': '2026-11-18T00:00:00.000Z',
};

void main() {
  test('PlanService uses the API plan routes and parses PublicPlan', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}?${request.url.query}');
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {
          'activityId': 'a1',
          'scheduledDate': '2026-11-18',
        });
      }
      final body = request.method == 'GET' ? [_plan] : _plan;
      return http.Response(jsonEncode(body), 200);
    });
    final service = PlanService(
      apiClient: ApiClient(baseUrl: 'http://x', httpClient: client),
    );

    final plans = await service.getPlans('c1', date: '2026-11-18');
    expect(plans.single.scheduledDate, '2026-11-18');
    await service.addActivityToPlan(
      childId: 'c1',
      activityId: 'a1',
      scheduledDate: '2026-11-18',
    );
    await service.updatePlanStatus(
      childId: 'c1',
      planId: 'p1',
      status: 'completed',
    );

    expect(calls, [
      'GET /api/v1/children/c1/plans?date=2026-11-18',
      'POST /api/v1/children/c1/plans?',
      'PATCH /api/v1/children/c1/plans/p1?',
    ]);
  });
}
