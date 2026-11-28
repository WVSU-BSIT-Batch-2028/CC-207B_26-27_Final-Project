import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// A child's weekly summary of completed activities and observations.
@immutable
class WeeklySummary {
  /// Creates a [WeeklySummary].
  const WeeklySummary({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.completedActivityCount,
    required this.observedMilestoneCount,
    required this.totalPlannedActivities,
    required this.domainDistribution,
    required this.topActivityIds,
    required this.reflectionPrompt,
    required this.generatedAt,
  });

  /// Creates a [WeeklySummary] from a decoded JSON object.
  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      id: json['id'] as String,
      weekStartDate: json['weekStartDate'] as String,
      weekEndDate: json['weekEndDate'] as String,
      completedActivityCount: (json['completedActivityCount'] as num).toInt(),
      observedMilestoneCount: (json['observedMilestoneCount'] as num).toInt(),
      totalPlannedActivities: (json['totalPlannedActivities'] as num).toInt(),
      domainDistribution: (json['domainDistribution'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      topActivityIds: (json['topActivityIds'] as List<dynamic>).cast<String>(),
      reflectionPrompt: json['reflectionPrompt'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  /// ISO week identifier (for example, `2026-W43`).
  final String id;

  /// Monday start date of the week in `YYYY-MM-DD` format.
  final String weekStartDate;

  /// Sunday end date of the week in `YYYY-MM-DD` format.
  final String weekEndDate;

  /// Number of planned activities completed during the week.
  final int completedActivityCount;

  /// Number of milestone observations recorded during the week.
  final int observedMilestoneCount;

  /// Total number of activities scheduled during the week.
  final int totalPlannedActivities;

  /// Count of completed activities grouped by developmental domain key.
  final Map<String, int> domainDistribution;

  /// Identifiers of the most frequently completed activities in the week.
  final List<String> topActivityIds;

  /// Factual, non-diagnostic reflection prompt summarizing the week.
  final String reflectionPrompt;

  /// Timestamp when the weekly summary was generated.
  final DateTime generatedAt;

  /// Whether zero completed activities and zero observations were recorded.
  bool get isEmptyWeek =>
      completedActivityCount == 0 && observedMilestoneCount == 0;

  /// Human-readable date range label (for example, `Oct 19 – 25, 2026`).
  String get formattedRange {
    final start = DateTime.tryParse(weekStartDate);
    final end = DateTime.tryParse(weekEndDate);
    if (start == null || end == null) {
      return '$weekStartDate – $weekEndDate';
    }
    final startMonth = DateFormat('MMM').format(start);
    final endMonth = DateFormat('MMM').format(end);
    final year = DateFormat('yyyy').format(end);

    if (start.month == end.month) {
      return '$startMonth ${start.day} – ${end.day}, $year';
    }
    return '$startMonth ${start.day} – $endMonth ${end.day}, $year';
  }

  /// Serializes this [WeeklySummary] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weekStartDate': weekStartDate,
      'weekEndDate': weekEndDate,
      'completedActivityCount': completedActivityCount,
      'observedMilestoneCount': observedMilestoneCount,
      'totalPlannedActivities': totalPlannedActivities,
      'domainDistribution': domainDistribution,
      'topActivityIds': topActivityIds,
      'reflectionPrompt': reflectionPrompt,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}
