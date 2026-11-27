import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/prescription.dart';

// A prescription cannot be taken (or remind) before its start date.
void main() {
  final rx = Prescription(
    id: 'rx-1',
    medicineName: 'Paracetamol',
    strength: '250mg',
    form: 'Tablet',
    instruction: 'Take 1 tablet - 1x a day',
    durationDays: 3,
    startDate: DateTime(2026, 11, 25),
    prescribedBy: 'Dr. Test',
    doctorPhone: '',
    prescribedOn: DateTime(2026, 11, 24),
  );

  test('not started the day before the start date', () {
    expect(rx.hasStartedOn(DateTime(2026, 11, 24, 23, 59)), isFalse);
  });

  test('started from the start date on, at any time of day', () {
    expect(rx.hasStartedOn(DateTime(2026, 11, 25, 0, 1)), isTrue);
    expect(rx.hasStartedOn(DateTime(2026, 11, 27, 20)), isTrue);
  });
}
