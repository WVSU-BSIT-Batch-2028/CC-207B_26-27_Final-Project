import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/doctor.dart';
import 'dashboard_service.dart';

/// Error returned when the doctor list cannot be loaded.
class DoctorBookingException implements Exception {
  /// Creates a doctor booking exception with a readable message.
  const DoctorBookingException(this.message);

  /// Message displayed to the user.
  final String message;

  @override
  String toString() => message;
}

/// Provides the doctors a patient can book (real doctor accounts).
///
/// Reads `users` where `role == 'doctor'`. The document id (the doctor's
/// uid) becomes [Doctor.id], and that uid is saved as `doctorId` on the
/// appointment, so only that doctor can see it.
///
/// Optional fields on the doctor's user document (a doctor without them
/// gets a default): `specialty`, `category` (General, Pediatrics or
/// Internal), `consultationType` and `consultationFee`.
/// It is separate from DoctorService, which handles the doctor dashboard.
class BookingDoctorService {
  BookingDoctorService._();

  /// Shared instance of the booking doctor service.
  static final BookingDoctorService instance = BookingDoctorService._();

  /// Retrieves the doctors available for appointment booking.
  ///
  /// The demo scenario allows the team to test the empty and error
  /// states without needing to change the data.
  Future<List<Doctor>> fetchDoctors() async {
    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const DoctorBookingException(
          "We couldn't load the doctors. Check your connection and try again.",
        );

      case DemoScenario.empty:
        return [];

      case DemoScenario.normal:
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
          return doctors;
        } on FirebaseException {
          throw const DoctorBookingException(
            "We couldn't load the doctors. Check your connection and try again.",
          );
        }
    }
  }

  /// Builds a [Doctor] from a `users` document of a doctor.
  @visibleForTesting
  Doctor doctorFrom(String uid, Map<String, dynamic> data) {
    final specialty = _text(data['specialty'], 'General Practitioner');
    final fee = data['consultationFee'];

    return Doctor(
      id: uid,
      name: _text(data['fullName'], 'Doctor'),
      specialty: specialty,
      category: _text(data['category'], _categoryFor(specialty)),
      nextAvailable: 'Pick a date and time',
      consultationType: _text(data['consultationType'], 'Clinic Visit'),
      consultationFee: fee is num ? fee.toDouble() : 500,
    );
  }

  /// The filter chip (General, Pediatrics, Internal) for a specialty.
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
