import 'package:flutter/foundation.dart';

/// A play or learning activity in the catalog.
@immutable
class Activity {
  /// Creates an [Activity].
  const Activity({
    required this.id,
    required this.title,
    required this.type,
    required this.language,
    required this.domain,
    required this.ageBand,
    required this.durationMinutes,
    required this.durationEstimate,
    required this.setting,
    required this.materials,
    required this.instructions,
    required this.limitations,
    required this.status,
    required this.provenanceSource,
  });

  /// Creates an [Activity] from a decoded JSON object.
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      language: json['language'] as String,
      domain: json['domain'] as String,
      ageBand: json['ageBand'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      durationEstimate: json['durationEstimate'] as String,
      setting: json['setting'] as String,
      materials: (json['materials'] as List<dynamic>).cast<String>(),
      instructions: (json['instructions'] as List<dynamic>).cast<String>(),
      limitations: json['limitations'] as String,
      status: json['status'] as String,
      provenanceSource: json['provenanceSource'] as String,
    );
  }

  /// Wire status for formally reviewed and approved catalog activities.
  static const String statusReviewedApproved = 'reviewed_approved';

  /// Wire status for source-checked catalog entries and rhymes.
  static const String statusSourceChecked = 'source_checked';

  /// Wire status for custom inline plan snapshots.
  static const String statusCustomSnapshot = 'custom_snapshot';

  /// Unique catalog activity identifier.
  final String id;

  /// Caregiver-facing activity title.
  final String title;

  /// Catalog entry type (for example, `activity`).
  final String type;

  /// ISO language code (`en`, `fil`, or `hil`).
  final String language;

  /// Developmental play domain (`cognitive`, `motor`, `language`, `socioEmotional`).
  final String domain;

  /// Target developmental age band (for example, `12-23m`).
  final String ageBand;

  /// Approximate play duration in minutes.
  final int durationMinutes;

  /// Human-readable duration label (for example, `10–15 mins`).
  final String durationEstimate;

  /// Recommended play setting (`indoor`, `outdoor`, or `either`).
  final String setting;

  /// Household materials used during the activity.
  final List<String> materials;

  /// Ordered step-by-step instructions for caregivers.
  final List<String> instructions;

  /// Safety and supervision notes for caregivers.
  final String limitations;

  /// Content publication status returned by the catalog API.
  final String status;

  /// Published early-learning framework or citation backing the activity.
  final String provenanceSource;

  /// Serializes this [Activity] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'language': language,
      'domain': domain,
      'ageBand': ageBand,
      'durationMinutes': durationMinutes,
      'durationEstimate': durationEstimate,
      'setting': setting,
      'materials': materials,
      'instructions': instructions,
      'limitations': limitations,
      'status': status,
      'provenanceSource': provenanceSource,
    };
  }
}
