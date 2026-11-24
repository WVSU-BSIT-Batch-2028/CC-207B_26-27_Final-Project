import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/reminder_setting.dart';

// Tests for when a reminder is due (ReminderSetting.timesOn), the logic the
// ReminderScheduler uses. No Firebase or timers needed.
void main() {
  final start = DateTime(2026, 11, 24);

  test('every 8 hours is due at 12:00 AM, 8:00 AM and 4:00 PM', () {
    final r = ReminderSetting(
      prescriptionId: 'rx-1',
      mode: ReminderMode.every8Hours,
      startDate: start,
      notificationsEnabled: true,
    );
    expect(r.timesOn(DateTime(2026, 11, 25, 13, 30)), [
      DateTime(2026, 11, 25, 0),
      DateTime(2026, 11, 25, 8),
      DateTime(2026, 11, 25, 16),
    ]);
  });

  test('custom time is due once a day at the chosen time', () {
    final r = ReminderSetting(
      prescriptionId: 'rx-1',
      mode: ReminderMode.customTime,
      startDate: start,
      notificationsEnabled: true,
      customHour: 20,
      customMinute: 5,
    );
    expect(r.timesOn(DateTime(2026, 11, 24, 9)), [DateTime(2026, 11, 24, 20, 5)]);
  });

  test('nothing is due before the start date', () {
    final r = ReminderSetting(
      prescriptionId: 'rx-1',
      mode: ReminderMode.every8Hours,
      startDate: start,
      notificationsEnabled: true,
    );
    expect(r.timesOn(DateTime(2026, 11, 23, 23)), isEmpty);
  });
}
