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

/// Provides doctor information for the patient appointment booking flow.
///
/// This service currently uses mock data and simulates a network delay.
/// It is separate from DoctorService, which handles the doctor dashboard.
class BookingDoctorService {
  BookingDoctorService._();

  /// Shared instance of the booking doctor service.
  static final BookingDoctorService instance = BookingDoctorService._();

  /// Retrieves the available doctors for appointment booking.
  ///
  /// The demo scenario allows the team to test normal, empty, and error
  /// responses without needing a live backend.
  Future<List<Doctor>> fetchDoctors() async {
    await Future<void>.delayed(const Duration(seconds: 1));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const DoctorBookingException(
          "We couldn't load the doctors. Check your connection and try again.",
        );

      case DemoScenario.empty:
        return [];

      case DemoScenario.normal:
        return const [
          Doctor(
            id: 'doc-001',
            name: 'Dr. Elena Cruz',
            specialty: 'General Practitioner',
            category: 'General',
            nextAvailable: 'Today, 2:00 PM',
            consultationType: 'Clinic Visit',
            consultationFee: 500,
          ),
          Doctor(
            id: 'doc-002',
            name: 'Dr. Miguel Reyes',
            specialty: 'Pediatrician',
            category: 'Pediatrics',
            nextAvailable: 'Tomorrow, 9:00 AM',
            consultationType: 'Video Consultation',
            consultationFee: 650,
          ),
          Doctor(
            id: 'doc-003',
            name: 'Dr. Andrea Santos',
            specialty: 'Internal Medicine',
            category: 'Internal',
            nextAvailable: 'Tomorrow, 10:30 AM',
            consultationType: 'Clinic Visit',
            consultationFee: 700,
          ),
          Doctor(
            id: 'doc-004',
            name: 'Dr. Rafael Mendoza',
            specialty: 'General Practitioner',
            category: 'General',
            nextAvailable: 'Friday, 1:00 PM',
            consultationType: 'Video Consultation',
            consultationFee: 500,
          ),
          Doctor(
            id: 'doc-005',
            name: 'Dr. Sofia Villanueva',
            specialty: 'Pediatrician',
            category: 'Pediatrics',
            nextAvailable: 'Friday, 3:00 PM',
            consultationType: 'Clinic Visit',
            consultationFee: 650,
          ),
        ];
    }
  }
}