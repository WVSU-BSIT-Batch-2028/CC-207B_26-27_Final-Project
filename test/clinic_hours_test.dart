import 'package:flutter_test/flutter_test.dart';
import 'package:health360/core/constants/clinic_hours.dart';

// Tests for the clinic hours used by booking and Edit Appointment.
void main() {
  final now = DateTime(2026, 11, 24, 7); // Tuesday 7:00 AM

  test('8:00 AM to 4:30 PM on Monday to Saturday can be booked', () {
    expect(ClinicHours.validate(DateTime(2026, 11, 24, 8, 0), now: now), isNull);
    expect(ClinicHours.validate(DateTime(2026, 11, 24, 16, 30), now: now), isNull);
    expect(ClinicHours.validate(DateTime(2026, 11, 28, 10), now: now), isNull); // Saturday
  });

  test('outside clinic hours is refused', () {
    expect(ClinicHours.validate(DateTime(2026, 11, 25, 3), now: now), isNotNull);
    expect(ClinicHours.validate(DateTime(2026, 11, 25, 16, 45), now: now), isNotNull);
  });

  test('Sundays are closed', () {
    final sunday = DateTime(2026, 11, 29, 10);
    expect(ClinicHours.isOpenDay(sunday), isFalse);
    expect(ClinicHours.validate(sunday, now: now), contains('Sundays'));
    expect(ClinicHours.nextOpenDay(sunday), DateTime(2026, 11, 30)); // Monday
  });

  test('the past is refused', () {
    expect(ClinicHours.validate(DateTime(2026, 11, 23, 9), now: now), isNotNull);
  });
}
