import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor.dart';
import 'dashboard_service.dart';

/// Error returned when the doctor list cannot be loaded.
class DoctorBookingException implements Exception {
  const DoctorBookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Provides the doctors a patient can book.
///
/// Every doctor is a `users/{uid}` document with `role: "doctor"`. Their
/// booking details are fields of that same document, so a doctor account
/// created in the Firebase console appears here without changing the code:
///
///   fullName          "Dr. Elena Cruz"           (required)
///   specialty         "General Practitioner"     (default: General Practitioner)
///   consultationType  "Clinic Visit" or "Video Consultation" (default: Clinic Visit)
///   consultationFee   500                        (number; default: 500)
///   category          "General" / "Pediatrics" / "Internal" (optional; worked
///                     out from the specialty when missing)
///
/// The document ID (the doctor's uid) is kept as the doctor's id, so
/// appointments are assigned to the right account.
class BookingDoctorService {
  BookingDoctorService._();

  static final BookingDoctorService instance = BookingDoctorService._();

  /// Shown under each doctor. There is no live availability calendar, so
  /// the patient picks the date and time in the next step.
  static const String _pickYourTime = 'Pick your preferred date and time';

  /// Retrieves the registered doctors a patient can book (`users` where
  /// role is "doctor"), sorted by name.
  ///
  /// The demo scenario (long-press the avatar on Home) shows the empty and
  /// error states without changing the Firestore data.
  Future<List<Doctor>> fetchDoctors() async {
    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const DoctorBookingException(
          "We couldn't load the doctors. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const <Doctor>[];
      case DemoScenario.normal:
        break;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();

      final doctors = [
        for (final document in snapshot.docs)
          doctorFrom(document.id, document.data()),
      ];

      doctors.sort((a, b) => a.name.compareTo(b.name));

      return List.unmodifiable(doctors);
    } on FirebaseException catch (e) {
      throw DoctorBookingException(
        e.code == 'permission-denied'
            ? 'You do not have permission to load registered doctors.'
            : "We couldn't load the doctors. Check your connection and try again.",
      );
    }
  }

  /// Builds a Doctor from a Firebase `users` document (fields listed above).
  /// Public: the doctor Home and drawer also use it for the specialty.
  Doctor doctorFrom(String uid, Map<String, dynamic> data) {
    final specialty = _text(data['specialty'], 'General Practitioner');
    final fee = data['consultationFee'];

    return Doctor(
      id: uid,
      name: _withTitle(_text(data['fullName'], '')),
      specialty: specialty,
      category: _text(data['category'], _categoryFor(specialty)),
      nextAvailable: _pickYourTime,
      consultationType: _text(data['consultationType'], 'Clinic Visit'),
      consultationFee: fee is num ? fee.toDouble() : 500.0,
    );
  }

  /// "Elena Cruz" -> "Dr. Elena Cruz"; empty -> "Doctor".
  String _withTitle(String name) {
    if (name.isEmpty) return 'Doctor';
    return name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';
  }

  /// Determines the category used by the specialty filter.
  String _categoryFor(String specialty) {
    final text = specialty.toLowerCase();

    if (text.contains('pediatric')) return 'Pediatrics';
    if (text.contains('internal')) return 'Internal';

    return 'General';
  }

  String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }
}
