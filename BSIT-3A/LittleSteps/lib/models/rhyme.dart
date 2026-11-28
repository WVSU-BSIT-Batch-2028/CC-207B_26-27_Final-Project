import 'package:flutter/foundation.dart';

import '../utils/domain_labels.dart';
import 'activity.dart';

/// A traditional Philippine children's rhyme paired with a play prompt.
@immutable
class PhilippineRhyme {
  /// Creates a [PhilippineRhyme].
  const PhilippineRhyme({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.domainLabel,
    required this.language,
    required this.lyrics,
    required this.actionPrompt,
    this.materials = const ['None required'],
    this.durationMinutes = 5,
    this.provenanceSource =
        'Traditional Philippine Children\'s Rhyme & Folk Song',
  });

  /// Creates a [PhilippineRhyme] from a decoded catalog JSON object.
  factory PhilippineRhyme.fromJson(Map<String, dynamic> json) {
    final lyricsRaw = json['lyrics'] as List<dynamic>? ?? const [];
    final materialsRaw =
        json['materials'] as List<dynamic>? ?? const ['None required'];
    return PhilippineRhyme(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      domain: json['domain'] as String? ?? AppDomains.language,
      domainLabel: json['domainLabel'] as String? ?? 'Talking',
      language: json['language'] as String? ?? AppLanguages.filipino,
      lyrics: lyricsRaw.map((e) => e.toString()).toList(),
      actionPrompt: json['actionPrompt'] as String? ?? '',
      materials: materialsRaw.map((e) => e.toString()).toList(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 5,
      provenanceSource:
          json['provenanceSource'] as String? ??
          'Traditional Philippine Children\'s Rhyme & Folk Song',
    );
  }

  /// Unique identifier for this rhyme.
  final String id;

  /// Display title of the rhyme.
  final String title;

  /// Short subtitle describing the play focus.
  final String subtitle;

  /// Developmental domain key matching the catalog schema.
  final String domain;

  /// Caregiver-facing label for [domain].
  final String domainLabel;

  /// ISO language code of the rhyme lyrics.
  final String language;

  /// Lines of lyrics sung with the child.
  final List<String> lyrics;

  /// Movement or interaction cue performed while singing.
  final String actionPrompt;

  /// Optional household items used during the rhyme.
  final List<String> materials;

  /// Estimated duration in minutes.
  final int durationMinutes;

  /// Published cultural or educational citation for this rhyme.
  final String provenanceSource;

  /// Serializes this [PhilippineRhyme] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'domain': domain,
      'domainLabel': domainLabel,
      'language': language,
      'lyrics': lyrics,
      'actionPrompt': actionPrompt,
      'materials': materials,
      'durationMinutes': durationMinutes,
      'provenanceSource': provenanceSource,
    };
  }

  /// Converts this rhyme into an [Activity] that can be scheduled in a plan.
  Activity toActivity({String? childNickname}) {
    final name = childNickname ?? 'your child';
    return Activity(
      id: id,
      title: 'Sing & Play: $title',
      type: 'rhyme',
      language: language,
      setting: PlaySetting.either,
      ageBand: 'all',
      domain: domain,
      durationMinutes: durationMinutes,
      durationEstimate: '$durationMinutes mins',
      materials: materials,
      instructions: [
        'Sit together in a comfortable spot facing $name.',
        'Sing through the rhyme with expressive hand motions and rhythm.',
        actionPrompt,
        'Pause and invite $name to copy your gestures or sound out favorite words.',
      ],
      provenanceSource: provenanceSource,
      status: Activity.statusSourceChecked,
      limitations: 'Shared cultural singing and bonding routine.',
    );
  }
}
