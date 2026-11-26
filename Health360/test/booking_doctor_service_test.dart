import 'package:flutter_test/flutter_test.dart';
import 'package:health360/services/booking_doctor_service.dart';

// Tests for how a doctor's `users` document becomes a bookable Doctor.
// No Firebase needed: doctorFrom only reads the map.
void main() {
  final service = BookingDoctorService.instance;

  test('reads the booking details from the document', () {
    final d = service.doctorFrom('uid-1', {
      'fullName': 'Dr. Andrea Santos',
      'specialty': 'Internal Medicine',
      'consultationType': 'Video Consultation',
      'consultationFee': 700,
    });
    expect(d.id, 'uid-1');
    expect(d.name, 'Dr. Andrea Santos');
    expect(d.specialty, 'Internal Medicine');
    expect(d.category, 'Internal');
    expect(d.consultationType, 'Video Consultation');
    expect(d.consultationFee, 700.0);
  });

  test('missing fields use safe defaults and the name gets "Dr."', () {
    final d = service.doctorFrom('uid-2', {'fullName': 'Miguel Reyes'});
    expect(d.name, 'Dr. Miguel Reyes');
    expect(d.specialty, 'General Practitioner');
    expect(d.category, 'General');
    expect(d.consultationType, 'Clinic Visit');
    expect(d.consultationFee, 500.0);
  });

  test('pediatric specialties go in the Pediatrics filter', () {
    expect(service.doctorFrom('u', {'specialty': 'Pediatrician'}).category, 'Pediatrics');
  });
}
