import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/prescription.dart';

/// Builds a prescription that starts on [start] and lasts [days] days.
Prescription _rx(DateTime start, int days, {DateTime? refill}) => Prescription(
      id: 'test',
      medicineName: 'Amoxicillin',
      strength: '500mg',
      form: 'Capsule',
      instruction: 'Take 1 capsule - 2x a day',
      durationDays: days,
      startDate: start,
      prescribedBy: 'Dr. Test',
      doctorPhone: '09123456789',
      prescribedOn: start,
      refillDate: refill,
    );

void main() {
  group('Prescription', () {
    test('title joins name and strength', () {
      expect(_rx(DateTime(2026, 9, 1), 5).title, 'Amoxicillin 500mg');
    });

    test('is active during the treatment period', () {
      final rx = _rx(DateTime(2026, 9, 1), 7); // ends Sept 8
      expect(rx.isActiveOn(DateTime(2026, 9, 1)), isTrue);
      expect(rx.isActiveOn(DateTime(2026, 9, 7, 23, 59)), isTrue);
    });

    test('is not active once the treatment period is over', () {
      final rx = _rx(DateTime(2026, 9, 1), 7);
      expect(rx.isActiveOn(DateTime(2026, 9, 8)), isFalse);
      expect(rx.isActiveOn(DateTime(2026, 10, 1)), isFalse);
    });

    test('refill is available on and after the refill date', () {
      final rx = _rx(DateTime(2026, 9, 1), 7, refill: DateTime(2026, 9, 10));
      expect(rx.isRefillAvailableOn(DateTime(2026, 9, 9)), isFalse);
      expect(rx.isRefillAvailableOn(DateTime(2026, 9, 10)), isTrue);
      expect(rx.isRefillAvailableOn(DateTime(2026, 9, 20)), isTrue);
    });

    test('refill is never available when there is no refill date', () {
      expect(_rx(DateTime(2026, 9, 1), 7).isRefillAvailableOn(DateTime(2027, 1, 1)), isFalse);
    });

    test('lastDay is the final day of the course', () {
      final rx = _rx(DateTime(2026, 9, 1), 7);
      expect(rx.lastDay, DateTime(2026, 9, 7));
      expect(rx.endDate, DateTime(2026, 9, 8));
    });
  });
}

