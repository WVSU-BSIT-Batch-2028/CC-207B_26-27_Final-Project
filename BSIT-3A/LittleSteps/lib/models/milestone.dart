import 'package:flutter/material.dart';

import '../utils/domain_labels.dart';

/// A saved caregiver observation for a developmental milestone prompt.
@immutable
class MilestoneObservation {
  /// Creates a [MilestoneObservation].
  const MilestoneObservation({
    required this.id,
    required this.childId,
    required this.milestoneId,
    required this.status,
    required this.observedDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [MilestoneObservation] from a decoded JSON object.
  factory MilestoneObservation.fromJson(Map<String, dynamic> json) {
    return MilestoneObservation(
      id: json['id'] as String,
      childId: json['childId'] as String,
      milestoneId: json['milestoneId'] as String,
      status: json['status'] as String,
      observedDate: json['observedDate'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Wire status recorded when the caregiver saw the milestone.
  static const String statusObserved = 'observed';

  /// Wire status recorded when the milestone has not been observed yet.
  static const String statusNotYetObserved = 'not_yet_observed';

  /// Unique identifier of the saved observation record.
  final String id;

  /// Identifier of the child profile associated with the observation.
  final String childId;

  /// Identifier of the catalog [MilestonePrompt].
  final String milestoneId;

  /// Recorded observation status (`observed` or `not_yet`).
  final String status;

  /// Calendar date of the observation in `YYYY-MM-DD` format.
  final String observedDate;

  /// Optional private caregiver note attached to the observation.
  final String? notes;

  /// Timestamp when the observation was created.
  final DateTime createdAt;

  /// Timestamp when the observation was last updated.
  final DateTime updatedAt;

  /// Whether the caregiver marked this prompt as observed.
  bool get isObserved => status == statusObserved;

  /// Serializes this [MilestoneObservation] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'milestoneId': milestoneId,
      'status': status,
      'observedDate': observedDate,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Early-learning developmental domains used to group milestone prompts.
enum MilestoneDomain {
  /// Problem-solving and exploration (`Thinking`).
  cognitive(AppDomains.cognitive, 'Thinking', Icons.psychology_outlined),

  /// Gross and fine movement (`Moving`).
  motor(AppDomains.motor, 'Moving', Icons.directions_run_outlined),

  /// Receptive and expressive communication (`Talking`).
  language(AppDomains.language, 'Talking', Icons.chat_bubble_outline),

  /// Social connection and emotional expression (`Feelings`).
  socioEmotional(AppDomains.socioEmotional, 'Feelings', Icons.favorite_border);

  const MilestoneDomain(this.key, this.label, this.icon);

  /// Wire domain key matching the backend API.
  final String key;

  /// Caregiver-facing domain label.
  final String label;

  /// Representative icon for domain headers and filter chips.
  final IconData icon;

  /// Resolves a [MilestoneDomain] from a backend wire [key].
  static MilestoneDomain fromKey(String key) {
    for (final domain in MilestoneDomain.values) {
      if (domain.key == key) return domain;
    }
    return MilestoneDomain.cognitive;
  }
}

/// An age-grouped observational prompt shown on the Milestones tab.
@immutable
class MilestonePrompt {
  /// Creates a [MilestonePrompt].
  const MilestonePrompt({
    required this.id,
    required this.domain,
    required this.title,
    required this.lookFor,
    required this.ageBand,
    this.provenance =
        'Source: CDC Developmental Milestones & Early Learning Guidelines',
  });

  /// Creates a [MilestonePrompt] from a decoded catalog JSON object.
  factory MilestonePrompt.fromJson(Map<String, dynamic> json) {
    final lookForRaw = json['lookFor'] as List<dynamic>? ?? const [];
    return MilestonePrompt(
      id: json['id'] as String? ?? '',
      domain: MilestoneDomain.fromKey(json['domain'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      lookFor: lookForRaw.map((e) => e.toString()).toList(),
      ageBand: json['ageBand'] as String? ?? '12-23 months',
      provenance:
          json['provenance'] as String? ??
          'Source: CDC Developmental Milestones & Early Learning Guidelines',
    );
  }

  /// Unique identifier of the milestone prompt.
  final String id;

  /// Developmental domain this prompt belongs to.
  final MilestoneDomain domain;

  /// Short observational prompt title.
  final String title;

  /// Concrete everyday examples caregivers can watch for during play.
  final List<String> lookFor;

  /// Human-readable age range for the prompt (for example, `12-23 months`).
  final String ageBand;

  /// Published guideline citation backing the prompt.
  final String provenance;

  /// Serializes this [MilestonePrompt] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'domain': domain.key,
      'title': title,
      'lookFor': lookFor,
      'ageBand': ageBand,
      'provenance': provenance,
    };
  }
}
