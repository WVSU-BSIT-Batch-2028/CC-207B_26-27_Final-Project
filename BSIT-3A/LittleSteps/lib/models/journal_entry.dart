import 'package:flutter/foundation.dart';

/// A private caregiver journal entry recorded for a child.
@immutable
class JournalEntry {
  /// Creates a [JournalEntry].
  const JournalEntry({
    required this.id,
    required this.childId,
    required this.entryDate,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [JournalEntry] from a decoded JSON object.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      childId: json['childId'] as String,
      entryDate: json['entryDate'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Unique identifier of the journal entry.
  final String id;

  /// Identifier of the child profile this note belongs to.
  final String childId;

  /// Calendar date of the entry in `YYYY-MM-DD` format.
  final String entryDate;

  /// Private caregiver note body.
  final String content;

  /// Timestamp when the entry was created.
  final DateTime createdAt;

  /// Timestamp when the entry was last updated.
  final DateTime updatedAt;

  /// Serializes this [JournalEntry] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'entryDate': entryDate,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
