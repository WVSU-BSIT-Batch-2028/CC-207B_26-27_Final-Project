import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/activity.dart';
import 'package:littlesteps/models/milestone.dart';
import 'package:littlesteps/models/summary.dart';

// Sample bodies follow the API response types in littlesteps-api.
void main() {
  test('Activity reads a catalog activity', () {
    final activity = Activity.fromJson({
      'id': 'act-1',
      'title': 'Stack the cups',
      'type': 'activity',
      'language': 'en',
      'setting': 'indoor',
      'ageBand': '12-23m',
      'domain': 'motor',
      'durationMinutes': 10,
      'durationEstimate': 'Under 10 mins',
      'materials': ['plastic cups'],
      'instructions': ['Show how to stack two cups.'],
      'provenanceSource': 'LittleSteps',
      'status': 'synthetic_fixture',
      'limitations': 'Watch small children near stacks.',
    });
    expect(activity.language, 'en');
    expect(activity.status, 'synthetic_fixture');
    expect(activity.materials, ['plastic cups']);
  });

  test('Activity rejects a body with missing fields', () {
    expect(() => Activity.fromJson({'id': 'act-1'}), throwsA(isA<TypeError>()));
  });

  test('MilestoneObservation reads a saved observation', () {
    final observation = MilestoneObservation.fromJson({
      'id': 'obs-1',
      'childId': 'c1',
      'milestoneId': 'm-walks',
      'status': 'observed',
      'observedDate': '2026-11-18',
      'createdAt': '2026-11-18T00:00:00.000Z',
      'updatedAt': '2026-11-18T00:00:00.000Z',
    });
    expect(observation.isObserved, isTrue);
    expect(observation.notes, isNull);
  });

  test('WeeklySummary reads the weekly summary', () {
    final summary = WeeklySummary.fromJson({
      'id': '2026-W47',
      'weekStartDate': '2026-11-16',
      'weekEndDate': '2026-11-22',
      'completedActivityCount': 3,
      'observedMilestoneCount': 1,
      'totalPlannedActivities': 5,
      'domainDistribution': {
        'cognitive': 1,
        'motor': 2,
        'language': 0,
        'socioEmotional': 0,
      },
      'topActivityIds': ['act-1'],
      'reflectionPrompt': 'What did your child enjoy most this week?',
      'generatedAt': '2026-11-18T00:00:00.000Z',
    });
    expect(summary.completedActivityCount, 3);
    expect(summary.domainDistribution['motor'], 2);
    expect(summary.topActivityIds, ['act-1']);
  });
}
