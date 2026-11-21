import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wvsu_wayfinder/data/schedule.dart';

ClassSession meeting(
  String id, {
  String room = 'CB203',
  String subject = 'CC 207 Web',
}) => ClassSession(
  id: id,
  subject: subject,
  weekday: 1,
  start: '08:00',
  end: '09:00',
  roomCodeRaw: room,
  professor: 'Prof. Cruz',
  remindMinutes: 15,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'import keeps existing classes, skips repeated meetings and survives reload',
    () async {
      final store = ScheduleStore();
      await store.load();
      await store.save(meeting('existing'));
      final count = await store.importClasses([
        meeting('duplicate', room: 'CB 203', subject: ' cc 207 web '),
        meeting('new', subject: 'CIT 210 Databases'),
        meeting('repeated-new', subject: 'CIT 210 Databases'),
      ]);
      expect(count, 1);
      expect(store.classes.map((c) => c.id), ['existing', 'new']);
      final reopened = ScheduleStore();
      await reopened.load();
      expect(reopened.classes.map((c) => c.id), ['existing', 'new']);
      expect(reopened.classes.last.professor, 'Prof. Cruz');
      expect(reopened.classes.last.remindMinutes, 15);
      expect(await reopened.importClasses([meeting('again')]), 0);
    },
  );
}
