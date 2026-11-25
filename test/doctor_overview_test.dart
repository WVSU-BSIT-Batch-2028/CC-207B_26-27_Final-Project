import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/appointment.dart';
import 'package:health360/models/appointment_status.dart';
import 'package:health360/models/prescription.dart';
import 'package:health360/services/doctor_overview.dart';

Appointment _appt(String patientId, DateTime at, AppointmentStatus status) => Appointment(
      id: '$patientId-${at.toIso8601String()}',
      title: 'Consultation',
      doctorName: 'Dr. Test',
      specialty: 'General Practitioner',
      dateTime: at,
      location: 'Clinic',
      status: status,
      patientId: patientId,
    );

Prescription _rx(DateTime start, int days) => Prescription(
      id: 'rx-${start.toIso8601String()}-$days',
      medicineName: 'Paracetamol',
      strength: '500mg',
      form: 'Tablet',
      instruction: 'Take 1 tablet - 2x a day',
      durationDays: days,
      startDate: start,
      prescribedBy: 'Dr. Test',
      doctorPhone: '',
      prescribedOn: start,
    );

void main() {
  final now = DateTime(2026, 11, 25, 14, 0);

  test('counts only today, active and current items', () {
    final overview = DoctorOverview.compute(
      appointments: [
        _appt('a', DateTime(2026, 11, 25, 9), AppointmentStatus.done), // today
        _appt('a', DateTime(2026, 11, 25, 10), AppointmentStatus.cancelled), // not counted
        _appt('b', DateTime(2026, 11, 25, 16), AppointmentStatus.confirmed), // today + active
        _appt('c', DateTime(2026, 11, 28, 9), AppointmentStatus.pending), // upcoming: active
        _appt('d', DateTime(2026, 11, 20, 9), AppointmentStatus.done), // past: not active
      ],
      prescriptions: [
        (patientId: 'e', prescription: _rx(DateTime(2026, 11, 24), 7)), // running
        (patientId: 'f', prescription: _rx(DateTime(2026, 11, 27), 5)), // starts later
        (patientId: 'g', prescription: _rx(DateTime(2026, 11, 1), 5)), // finished
      ],
      labResultDates: [
        (date: DateTime(2026, 11, 25), enteredAt: null), // test date today
        (date: DateTime(2026, 11, 20), enteredAt: DateTime(2026, 11, 25, 8)), // entered today
        (date: DateTime(2026, 11, 20), enteredAt: DateTime(2026, 11, 21)), // old
      ],
      now: now,
    );

    expect(overview.todayAppointments, 2);
    expect(overview.activePrescriptions, 2);
    expect(overview.activePatients, 4); // b, c, e, f
    expect(overview.todayLabResults, 2);
  });

  test('all zero with no data', () {
    final overview = DoctorOverview.compute(
      appointments: const [],
      prescriptions: const [],
      labResultDates: const [],
      now: now,
    );
    expect(overview.todayAppointments, 0);
    expect(overview.activePatients, 0);
    expect(overview.activePrescriptions, 0);
    expect(overview.todayLabResults, 0);
  });
}
