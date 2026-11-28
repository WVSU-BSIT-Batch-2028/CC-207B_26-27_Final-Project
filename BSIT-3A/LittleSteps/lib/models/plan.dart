import 'package:flutter/foundation.dart';

import '../utils/domain_labels.dart';
import 'activity.dart';

/// Inline snapshot of a custom, storybook, or rhyme activity stored on a plan.
@immutable
class CustomPlanActivity {
  /// Creates a [CustomPlanActivity].
  const CustomPlanActivity({
    required this.title,
    required this.domain,
    required this.durationMinutes,
    required this.setting,
    required this.materials,
    required this.instructions,
    this.safetyNotice,
    this.sourceLabel,
  });

  /// Builds a [CustomPlanActivity] from an in-memory [Activity].
  factory CustomPlanActivity.fromActivity(
    Activity activity, {
    String? sourceLabel,
  }) {
    final cleanMaterials = activity.materials
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .take(10)
        .map((m) => m.length > 60 ? m.substring(0, 60) : m)
        .toList();
    final cleanInstructions = activity.instructions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(6)
        .map((s) => s.length > 300 ? s.substring(0, 300) : s)
        .toList();
    final rawSafety = activity.limitations.trim();
    final safeNotice = rawSafety.isEmpty
        ? null
        : (rawSafety.length > 200 ? rawSafety.substring(0, 200) : rawSafety);
    final cleanTitle = activity.title.trim();
    return CustomPlanActivity(
      title: cleanTitle.length > 120
          ? cleanTitle.substring(0, 120)
          : (cleanTitle.isEmpty ? 'Custom play idea' : cleanTitle),
      domain: normalizeDomain(activity.domain),
      durationMinutes: activity.durationMinutes.clamp(1, 180),
      setting: normalizeSetting(activity.setting),
      materials: cleanMaterials,
      instructions: cleanInstructions.isNotEmpty
          ? cleanInstructions
          : const [
              'Play together at your child\'s pace with adult supervision.',
            ],
      safetyNotice: safeNotice,
      sourceLabel: sourceLabel,
    );
  }

  /// Creates a [CustomPlanActivity] from a decoded JSON object.
  factory CustomPlanActivity.fromJson(Map<String, dynamic> json) {
    return CustomPlanActivity(
      title: json['title'] as String,
      domain: json['domain'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      setting: json['setting'] as String,
      materials: (json['materials'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      instructions: (json['instructions'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      safetyNotice: json['safetyNotice'] as String?,
      sourceLabel: json['sourceLabel'] as String?,
    );
  }

  /// Caregiver-facing activity title.
  final String title;

  /// Developmental domain key (`cognitive`, `motor`, `language`, `socioEmotional`).
  final String domain;

  /// Estimated play duration in minutes.
  final int durationMinutes;

  /// Play setting (`indoor`, `outdoor`, or `either`).
  final String setting;

  /// Household materials used during the activity.
  final List<String> materials;

  /// Ordered caregiver play instructions.
  final List<String> instructions;

  /// Optional supervision or safety reminder.
  final String? safetyNotice;

  /// Optional provenance label such as `Material adaptation` or `Storybook companion`.
  final String? sourceLabel;

  /// Normalizes a domain key to one of the four API-supported values.
  static String normalizeDomain(String raw) {
    switch (raw.toLowerCase()) {
      case AppDomains.cognitive:
        return AppDomains.cognitive;
      case AppDomains.motor:
        return AppDomains.motor;
      case AppDomains.language:
        return AppDomains.language;
      case 'socioemotional':
      case 'socio_emotional':
      case 'socio-emotional':
        return AppDomains.socioEmotional;
      default:
        return AppDomains.language;
    }
  }

  /// Normalizes a setting key to [PlaySetting.indoor], [PlaySetting.outdoor],
  /// or [PlaySetting.either].
  static String normalizeSetting(String raw) {
    switch (raw.toLowerCase()) {
      case PlaySetting.indoor:
        return PlaySetting.indoor;
      case PlaySetting.outdoor:
        return PlaySetting.outdoor;
      case PlaySetting.either:
        return PlaySetting.either;
      default:
        return PlaySetting.indoor;
    }
  }

  /// Serializes this snapshot to a JSON map for `POST /plans`.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'domain': domain,
      'durationMinutes': durationMinutes,
      'setting': setting,
      'materials': materials,
      'instructions': instructions,
      if (safetyNotice != null && safetyNotice!.isNotEmpty)
        'safetyNotice': safetyNotice,
      if (sourceLabel != null && sourceLabel!.isNotEmpty)
        'sourceLabel': sourceLabel,
    };
  }

  /// Converts this snapshot into an [Activity] for display on Today cards.
  Activity toActivity(String activityId) {
    return Activity(
      id: activityId,
      title: title,
      type: 'custom',
      language: 'en',
      domain: domain,
      ageBand: 'all',
      durationMinutes: durationMinutes,
      durationEstimate: '$durationMinutes mins',
      setting: setting,
      materials: materials,
      instructions: instructions,
      limitations: safetyNotice ?? '',
      status: Activity.statusCustomSnapshot,
      provenanceSource: '',
    );
  }
}

/// A planned activity for a child on a given date.
///
/// Mirrors the API `PublicPlan`. Catalog plans resolve details from [Activity]
/// by [activityId], while custom, storybook, and rhyme plans carry an inline
/// [customActivity] snapshot.
@immutable
class PlanItem {
  /// Creates a [PlanItem].
  const PlanItem({
    required this.id,
    required this.childId,
    required this.activityId,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
    this.durationMinutes,
    this.feedbackNote,
    this.customActivity,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [PlanItem] from a decoded JSON object.
  factory PlanItem.fromJson(Map<String, dynamic> json) {
    final rawCustom = json['customActivity'];
    return PlanItem(
      id: json['id'] as String,
      childId: json['childId'] as String,
      activityId: json['activityId'] as String,
      scheduledDate: json['scheduledDate'] as String,
      status: json['status'] as String,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      feedbackNote: json['feedbackNote'] as String?,
      customActivity: rawCustom is Map<String, dynamic>
          ? CustomPlanActivity.fromJson(rawCustom)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Wire status for an upcoming planned activity.
  static const String statusPlanned = 'planned';

  /// Wire status for a completed activity.
  static const String statusCompleted = 'completed';

  /// Wire status for a skipped activity.
  static const String statusSkipped = 'skipped';

  /// Unique identifier of the scheduled plan record.
  final String id;

  /// Identifier of the child profile this plan belongs to.
  final String childId;

  /// Identifier of the scheduled catalog or custom [Activity].
  final String activityId;

  /// Local calendar date in `YYYY-MM-DD` form.
  final String scheduledDate;

  /// Plan status (`planned`, `completed`, or `skipped`).
  final String status;

  /// Timestamp when the activity was marked completed, if completed.
  final DateTime? completedAt;

  /// Optional play duration recorded in minutes.
  final int? durationMinutes;

  /// Optional caregiver feedback note on the session.
  final String? feedbackNote;

  /// Optional inline snapshot for non-catalog play activities.
  final CustomPlanActivity? customActivity;

  /// Timestamp when the plan record was created.
  final DateTime createdAt;

  /// Timestamp when the plan record was last updated.
  final DateTime updatedAt;

  /// Whether this activity has been completed.
  bool get isCompleted => status == statusCompleted;

  /// Serializes this [PlanItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'activityId': activityId,
      'scheduledDate': scheduledDate,
      'status': status,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (feedbackNote != null) 'feedbackNote': feedbackNote,
      if (customActivity != null) 'customActivity': customActivity!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
