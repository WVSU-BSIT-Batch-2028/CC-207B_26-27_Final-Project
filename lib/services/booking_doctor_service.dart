import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/doctor.dart';
import 'dashboard_service.dart';

/// Error returned when the doctor list cannot be loaded.
class DoctorBookingException implements Exception {
  const DoctorBookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Original Health360 doctor profile information.
class _DoctorProfile {
  const _DoctorProfile({
    required this.name,
    required this.specialty,
    required this.category,
    required this.nextAvailable,
    required this.consultationType,
    required this.consultationFee,
  });

  final String name;
  final String specialty;
  final String category;
  final String nextAvailable;
  final String consultationType;
  final double consultationFee;
}

/// Provides the doctors a patient can book.
///
/// Retrieves real doctor accounts from Firestore and restores
/// the original Health360 information for the five known doctors.
class BookingDoctorService {
  BookingDoctorService._();

  static final BookingDoctorService instance = BookingDoctorService._();

  /// Original doctor profiles mapped to their actual Firebase UIDs.
  static const Map<String, _DoctorProfile> _doctorProfiles = {
    'CHFpIARAwchObyj36q8eiOvsp2G3': _DoctorProfile(
      name: 'Dr. Elena Cruz',
      specialty: 'General Practitioner',
      category: 'General',
      nextAvailable: 'Today, 2:00 PM',
      consultationType: 'Clinic Visit',
      consultationFee: 500.0,
    ),
    'OxrNwBrh3rTv7AuWNh5my5jvdC53': _DoctorProfile(
      name: 'Dr. Miguel Reyes',
      specialty: 'Pediatrician',
      category: 'Pediatrics',
      nextAvailable: 'Tomorrow, 9:00 AM',
      consultationType: 'Video Consultation',
      consultationFee: 650.0,
    ),
    'hVpQuMpcSQPHBbP3nRfkBCCiYU32': _DoctorProfile(
      name: 'Dr. Andrea Santos',
      specialty: 'Internal Medicine',
      category: 'Internal',
      nextAvailable: 'Tomorrow, 10:30 AM',
      consultationType: 'Clinic Visit',
      consultationFee: 700.0,
    ),
    'UkGPnVq37fZP5SLQDXKqhECxr582': _DoctorProfile(
      name: 'Dr. Rafael Mendoza',
      specialty: 'General Practitioner',
      category: 'General',
      nextAvailable: 'Friday, 1:00 PM',
      consultationType: 'Video Consultation',
      consultationFee: 500.0,
    ),
    '4M3lq0ZJ3JdcPw4oSnqulawLobG3': _DoctorProfile(
      name: 'Dr. Sofia Villanueva',
      specialty: 'Pediatrician',
      category: 'Pediatrics',
      nextAvailable: 'Friday, 3:00 PM',
      consultationType: 'Clinic Visit',
      consultationFee: 650.0,
    ),
  };

  /// Retrieves registered doctors from Firestore.
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

          return List.unmodifiable(doctors);
        } on FirebaseException catch (e) {
          throw DoctorBookingException(
            e.code == 'permission-denied'
                ? 'You do not have permission to load registered doctors.'
                : "We couldn't load the doctors. Check your connection and try again.",
          );
        }
    }
  }

  /// Builds a Doctor from a Firebase users document.
  ///
  /// Known doctors use their original hardcoded profile details.
  /// Other registered doctors use their Firestore profile information.
  @visibleForTesting
  Doctor doctorFrom(String uid, Map<String, dynamic> data) {
    final profile = _doctorProfiles[uid];

    final firestoreSpecialty = _text(
      data['specialty'],
      'General Practitioner',
    );

    final specialty = profile?.specialty ?? firestoreSpecialty;

    final fee = data['consultationFee'];

    return Doctor(
      // Actual Firebase UID is retained for appointment ownership.
      id: uid,

      name: profile?.name ?? _text(data['fullName'], 'Doctor'),

      specialty: specialty,

      category:
          profile?.category ?? _text(data['category'], _categoryFor(specialty)),

      nextAvailable: profile?.nextAvailable ?? 'Pick a date and time',

      consultationType: profile?.consultationType ??
          _text(data['consultationType'], 'Clinic Visit'),

      consultationFee:
          profile?.consultationFee ?? (fee is num ? fee.toDouble() : 500.0),
    );
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
