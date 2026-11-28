import 'package:littlesteps/models/summary.dart';

/// Sample weekly summary fixtures used strictly by widget tests.
final Map<String, WeeklySummary> sampleWeeklySummaries = {
  '2026-W43': WeeklySummary(
    id: '2026-W43',
    weekStartDate: '2026-10-19',
    weekEndDate: '2026-10-25',
    completedActivityCount: 4,
    observedMilestoneCount: 1,
    totalPlannedActivities: 5,
    domainDistribution: const {
      'cognitive': 1,
      'motor': 1,
      'language': 2,
      'socioEmotional': 0,
    },
    topActivityIds: const ['act-1', 'act-2'],
    reflectionPrompt: 'Maya enjoyed talking games this week. Next time you read together, pause on a page and let her point first.',
    generatedAt: DateTime(2026, 10, 25),
  ),
  '2026-W42': WeeklySummary(
    id: '2026-W42',
    weekStartDate: '2026-10-12',
    weekEndDate: '2026-10-18',
    completedActivityCount: 2,
    observedMilestoneCount: 0,
    totalPlannedActivities: 4,
    domainDistribution: const {
      'cognitive': 0,
      'motor': 1,
      'language': 1,
      'socioEmotional': 0,
    },
    topActivityIds: const ['act-3'],
    reflectionPrompt: 'You and Maya shared quiet moments of connection during everyday routines.',
    generatedAt: DateTime(2026, 10, 18),
  ),
  '2026-W41': WeeklySummary(
    id: '2026-W41',
    weekStartDate: '2026-10-05',
    weekEndDate: '2026-10-11',
    completedActivityCount: 0,
    observedMilestoneCount: 0,
    totalPlannedActivities: 0,
    domainDistribution: const {
      'cognitive': 0,
      'motor': 0,
      'language': 0,
      'socioEmotional': 0,
    },
    topActivityIds: const [],
    reflectionPrompt: '',
    generatedAt: DateTime(2026, 10, 11),
  ),
};
