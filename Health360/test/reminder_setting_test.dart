import 'package:flutter_test/flutter_test.dart';
import 'package:health360/models/reminder_setting.dart';

void main() {
  group('ReminderSetting', () {
    test('summary for every 8 hours', () {
      final r = ReminderSetting(
        prescriptionId: 'rx-1',
        mode: ReminderMode.every8Hours,
        startDate: DateTime(2026, 9, 21),
        notificationsEnabled: true,
      );
      expect(r.summary, 'every 8 hours');
    });

    test('summary for a custom daily time', () {
      final r = ReminderSetting(
        prescriptionId: 'rx-1',
        mode: ReminderMode.customTime,
        startDate: DateTime(2026, 9, 21),
        notificationsEnabled: true,
        customHour: 20,
        customMinute: 5,
      );
      expect(r.summary, 'daily at 8:05 PM');
    });

    test('survives a trip through JSON', () {
      final original = ReminderSetting(
        prescriptionId: 'rx-2',
        mode: ReminderMode.customTime,
        startDate: DateTime(2026, 9, 21),
        notificationsEnabled: false,
        customHour: 7,
        customMinute: 30,
      );
      final copy = ReminderSetting.fromJson(original.toJson());

      expect(copy.prescriptionId, 'rx-2');
      expect(copy.mode, ReminderMode.customTime);
      expect(copy.startDate, DateTime(2026, 9, 21));
      expect(copy.notificationsEnabled, isFalse);
      expect(copy.customHour, 7);
      expect(copy.customMinute, 30);
    });
  });
}
