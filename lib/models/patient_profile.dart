import 'patient_record.dart';

/// The medical profile of one patient, stored in `patientProfiles/{uid}`.
///
/// The doctor fills it in with Edit Patient Info (the Firestore rules only
/// let doctors write it). The Patients list, Patient Details and Patient
/// Records read the same document.
///
/// Plain data: no widgets and no Firebase calls, so it can be unit tested.
class PatientProfile {
  const PatientProfile({
    this.age,
    this.sex = '',
    this.phone = '',
    this.condition = '',
    this.isActive = true,
    this.allergies = const [],
    this.immunizations = const [],
    this.history = const [],
  });

  /// Age in years, or null if not recorded.
  final int? age;

  /// "Female", "Male" or "Prefer not to say"; empty if not recorded.
  final String sex;

  /// Contact number; empty if not recorded.
  final String phone;

  /// Main condition shown in the Patients list, e.g. "Hypertension".
  final String condition;

  /// True = "Active" pill (under care now), false = "History" pill.
  final bool isActive;

  /// e.g. ["Penicillin", "Peanuts"]. Empty = none known.
  final List<String> allergies;

  /// e.g. ["Influenza (2024)"]. Empty = none recorded.
  final List<String> immunizations;

  /// Past and current conditions with the year they were diagnosed.
  final List<MedicalHistoryEntry> history;

  /// Builds a profile from a `patientProfiles` document (null = no profile yet).
  factory PatientProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PatientProfile();

    List<String> strings(Object? raw) => raw is List
        ? [for (final item in raw) if ('$item'.trim().isNotEmpty) '$item'.trim()]
        : const <String>[];

    final rawHistory = data['medicalHistory'];
    final age = data['age'];

    return PatientProfile(
      age: age is num ? age.toInt() : null,
      sex: (data['sex'] ?? '').toString().trim(),
      phone: (data['phone'] ?? '').toString().trim(),
      condition: (data['condition'] ?? '').toString().trim(),
      isActive: data['isActive'] != false,
      allergies: strings(data['allergies']),
      immunizations: strings(data['immunizations']),
      history: [
        if (rawHistory is List)
          for (final item in rawHistory)
            if (item is Map && '${item['condition'] ?? ''}'.trim().isNotEmpty)
              MedicalHistoryEntry(
                condition: '${item['condition']}'.trim(),
                diagnosedYear: item['diagnosedYear'] is num
                    ? (item['diagnosedYear'] as num).toInt()
                    : 0,
              ),
      ],
    );
  }

  /// The map saved to Firestore (the same field names the screens read).
  Map<String, dynamic> toMap() => {
        'age': age,
        'sex': sex,
        'phone': phone,
        'condition': condition,
        'isActive': isActive,
        'allergies': allergies,
        'immunizations': immunizations,
        'medicalHistory': [
          for (final entry in history)
            {'condition': entry.condition, 'diagnosedYear': entry.diagnosedYear},
        ],
      };
}

/// "Penicillin, Peanuts" -> ["Penicillin", "Peanuts"] (empty parts dropped).
List<String> splitList(String text) => [
      for (final part in text.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];

/// One history entry per line: "Hypertension (2019)" or just "Asthma".
/// A line without a year gets year 0 ("year not recorded").
List<MedicalHistoryEntry> parseHistory(String text) {
  final withYear = RegExp(r'^(.*?)\s*\((\d{4})\)\s*$');
  return [
    for (final raw in text.split('\n'))
      if (raw.trim().isNotEmpty)
        () {
          final line = raw.trim();
          final match = withYear.firstMatch(line);
          return match == null || match.group(1)!.trim().isEmpty
              ? MedicalHistoryEntry(condition: line, diagnosedYear: 0)
              : MedicalHistoryEntry(
                  condition: match.group(1)!.trim(),
                  diagnosedYear: int.parse(match.group(2)!),
                );
        }(),
  ];
}

/// The reverse of [parseHistory], to prefill the form.
String historyText(List<MedicalHistoryEntry> history) => [
      for (final entry in history)
        entry.diagnosedYear > 0
            ? '${entry.condition} (${entry.diagnosedYear})'
            : entry.condition,
    ].join('\n');
