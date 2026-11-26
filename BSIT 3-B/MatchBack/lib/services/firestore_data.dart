import 'package:cloud_firestore/cloud_firestore.dart';

/// Every field that holds a server time. Firestore returns these as
/// Timestamp objects, which the models cannot read directly.
const _timeFields = [
  'createdAt',
  'approvedAt',
  'readyAt',
  'returnedAt',
  'rejectedAt',
  'sentAt',
];

/// Returns a copy of a document's data where each server time is turned into
/// plain text (or null if it was not set yet). The models then read it
/// without needing to know about Firestore.
Map<String, dynamic> withTimestamps(Map<String, dynamic> data) {
  final result = {...data};

  for (final field in _timeFields) {
    final stored = data[field];
    result[field] = stored is Timestamp
        ? stored.toDate().toUtc().toIso8601String()
        : null;
  }

  return result;
}
