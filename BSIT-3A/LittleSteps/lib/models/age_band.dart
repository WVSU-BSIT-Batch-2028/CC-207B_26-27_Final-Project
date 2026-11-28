import 'package:flutter/foundation.dart';

/// One developmental age range a child can belong to, such as `12-23 months`.
@immutable
class AgeBand {
  /// Creates an [AgeBand] covering [minMonths] through [maxMonths].
  const AgeBand({
    required this.code,
    required this.label,
    required this.minMonths,
    required this.maxMonths,
  });

  /// API wire code for this band (for example, `12-23m`).
  final String code;

  /// Caregiver-facing label for this band (for example, `12-23 months`).
  final String label;

  /// Youngest supported age in this band, in months.
  final int minMonths;

  /// Oldest supported age in this band, in months.
  final int maxMonths;
}

/// Default catalog age-band wire code used when no child profile is selected.
const String defaultAgeBandCode = '12-23m';

/// Supported developmental age bands ordered from youngest to oldest.
const List<AgeBand> ageBands = [
  AgeBand(code: '0-5m', label: '0-5 months', minMonths: 0, maxMonths: 5),
  AgeBand(code: '6-11m', label: '6-11 months', minMonths: 6, maxMonths: 11),
  AgeBand(code: '12-23m', label: '12-23 months', minMonths: 12, maxMonths: 23),
  AgeBand(code: '24-35m', label: '24-35 months', minMonths: 24, maxMonths: 35),
  AgeBand(code: '36-47m', label: '36-47 months', minMonths: 36, maxMonths: 47),
  AgeBand(code: '48-59m', label: '48-59 months', minMonths: 48, maxMonths: 59),
  AgeBand(code: '60-71m', label: '60-71 months', minMonths: 60, maxMonths: 71),
];

/// Ordered milestone catalog age-band labels matching `GET /catalog/milestones`.
const List<String> milestoneAgeBands = [
  '0-11 months',
  '12-23 months',
  '24-35 months',
  '36-47 months',
  '48-59 months',
  '60-71 months',
];

/// Resolves the milestone catalog age-band label for an age in [months].
String milestoneAgeBandForMonths(int months) {
  if (months < 12) return milestoneAgeBands[0];
  if (months < 24) return milestoneAgeBands[1];
  if (months < 36) return milestoneAgeBands[2];
  if (months < 48) return milestoneAgeBands[3];
  if (months < 60) return milestoneAgeBands[4];
  return milestoneAgeBands[5];
}

/// Resolves the milestone catalog age-band label from a child [rawAgeBand] code.
String milestoneAgeBandForCode(String? rawAgeBand) {
  if (rawAgeBand == null || rawAgeBand.isEmpty) {
    return milestoneAgeBands[1];
  }
  final band = ageBandForCode(rawAgeBand);
  if (band != null) {
    return milestoneAgeBandForMonths(band.minMonths);
  }
  final match = RegExp(r'\d+').firstMatch(rawAgeBand);
  final months = int.tryParse(match?.group(0) ?? '');
  return milestoneAgeBandForMonths(months ?? 14);
}

/// Calculates whole months elapsed between [birthYear]/[birthMonth] and [now].
int ageInMonths({
  required int birthYear,
  required int birthMonth,
  required DateTime now,
}) {
  return (now.year * 12 + now.month) - (birthYear * 12 + birthMonth);
}

/// Finds the [AgeBand] containing [months], or `null` if outside `0-71`.
AgeBand? ageBandForMonths(int months) {
  for (final band in ageBands) {
    if (months >= band.minMonths && months <= band.maxMonths) {
      return band;
    }
  }
  return null;
}

/// Finds the [AgeBand] matching API [code], or `null` if unrecognized.
AgeBand? ageBandForCode(String code) {
  for (final band in ageBands) {
    if (band.code == code) {
      return band;
    }
  }
  return null;
}

/// Normalizes a child or filter [rawAgeBand] value into a catalog age-band code.
///
/// Accepts canonical wire codes (such as `12-23m`) as well as single-month
/// shorthand (such as `14m`), returning `null` if [rawAgeBand] is absent or
/// unrecognized.
String? normalizeCatalogAgeBandCode(String? rawAgeBand) {
  if (rawAgeBand == null || rawAgeBand.isEmpty) return null;
  if (ageBandForCode(rawAgeBand) != null) return rawAgeBand;
  final monthMatch = RegExp(r'^(\d{1,2})m$').firstMatch(rawAgeBand);
  final months = int.tryParse(monthMatch?.group(1) ?? '');
  if (months == null) return null;
  return ageBandForMonths(months)?.code;
}

/// Formats a child's age for caregiver-facing badges from [birthMonthYear] or
/// [ageBand].
String formatChildAgeLabel({
  required String ageBand,
  String? birthMonthYear,
  DateTime? now,
}) {
  if (birthMonthYear != null) {
    final parts = birthMonthYear.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        final age = ageInMonths(
          birthYear: year,
          birthMonth: month,
          now: now ?? DateTime.now(),
        );
        if (age >= 0) return '$age ${age == 1 ? 'month' : 'months'}';
      }
    }
  }
  final normalized = normalizeCatalogAgeBandCode(ageBand);
  if (normalized != null) {
    return ageBandForCode(normalized)?.label ?? ageBand;
  }
  if (ageBand.contains('month')) return ageBand;
  if (ageBand.endsWith('m')) {
    return '${ageBand.substring(0, ageBand.length - 1)} months';
  }
  return '$ageBand months';
}
