// Firestore saves dates as Timestamp objects. These two helpers convert
// between Timestamp and Dart's DateTime so every model does it the same way.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a Firestore value as a DateTime. Missing values become [fallback]
/// (or "now"), so a half-saved document never crashes the app.
DateTime readDate(Object? value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  return fallback ?? DateTime.now();
}

/// Reads an optional date: returns null when the field is missing.
DateTime? readOptionalDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

/// Reads a number field as a double, whether Firestore stored 50 or 50.0.
double readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return 0;
}
