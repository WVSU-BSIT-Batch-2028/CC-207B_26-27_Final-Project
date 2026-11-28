import 'package:flutter/foundation.dart';

/// A child profile record associated with a caregiver account.
@immutable
class Child {
  /// Creates a [Child].
  const Child({
    required this.id,
    required this.nickname,
    required this.ageBand,
    this.birthMonthYear,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [Child] from a decoded JSON object.
  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      ageBand: json['ageBand'] as String,
      birthMonthYear: json['birthMonthYear'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Unique identifier of the child profile.
  final String id;

  /// Short nickname chosen by the caregiver.
  final String nickname;

  /// Developmental age band code (for example, `12-23m`).
  final String ageBand;

  /// Optional birth year and month in `YYYY-MM` format.
  final String? birthMonthYear;

  /// Timestamp when the profile was created.
  final DateTime createdAt;

  /// Timestamp when the profile was last updated.
  final DateTime updatedAt;

  /// Serializes this [Child] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'ageBand': ageBand,
      if (birthMonthYear != null) 'birthMonthYear': birthMonthYear,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
