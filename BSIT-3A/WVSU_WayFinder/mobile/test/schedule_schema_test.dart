import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wvsu_wayfinder/data/schedule.dart';

const classesKey = 'wf.schedule.classes.v1';
ClassSession session({
  String id = 'legacy-id',
  String subject = 'CC 207 Web Systems',
  int weekday = 1,
  String start = '08:00',
  String end = '09:00',
  String tz = 'Asia/Manila',
  int? reminder = 15,
}) => ClassSession(
  id: id,
  subject: subject,
  weekday: weekday,
  start: start,
  end: end,
  roomCodeRaw: '',
  professor: null,
  remindMinutes: reminder,
  tz: tz,
  uploadId: '03dde612-25a0-4707-a07c-38bf0b9e4c68',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new class and upload identifiers are unique RFC 4122 UUID v4 values', () {
    final ids = List.generate(100, (_) => newScheduleId());
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(ids.every(pattern.hasMatch), isTrue);
    expect(ids.toSet(), hasLength(ids.length));
  });

  test(
    'SQL field names and nullable values survive a class row round trip',
    () {
      final row = session(id: newScheduleId(), reminder: null).toJson();
      expect(row.keys.toSet(), {
        'id',
        'upload_id',
        'subject',
        'weekday',
        'start_time',
        'end_time',
        'tz',
        'room_code_raw',
        'room_place_id',
        'professor_name',
        'remind_minutes',
      });
      expect(
        row,
        isNot(contains('user_id')),
      ); // Auth supplies the owner in SQL.
      expect(row['tz'], 'Asia/Manila');
      expect(row['remind_minutes'], isNull);
      expect(ClassSession.fromJson(row).toJson(), row);
      final sqlTimes = ClassSession.fromJson({
        ...row,
        'start_time': '08:00:00',
        'end_time': '09:00:00.000000',
      });
      expect(sqlTimes.start, '08:00');
      expect(sqlTimes.end, '09:00');
    },
  );

  test(
    'existing camelCase schedules retain IDs, room mapping and reminders',
    () async {
      SharedPreferences.setMockInitialValues({
        classesKey: jsonEncode([
          {
            'id': 'old-timestamp-id',
            'subject': 'CIT 210',
            'weekday': 4,
            'start': '13:30',
            'end': '15:00',
            'roomCodeRaw': 'CB 203',
            'roomPlaceId': 'room-demo-cb-203',
            'professor': 'Prof. Cruz',
            'remindMinutes': 15,
          },
        ]),
      });
      final store = ScheduleStore();
      await store.load();
      final old = store.classes.single;
      expect(old.id, 'old-timestamp-id');
      expect(old.roomPlaceId, 'room-demo-cb-203');
      expect(old.professor, 'Prof. Cruz');
      expect(old.tz, 'Asia/Manila');
      expect(old.remindMinutes, 15);
      await store.save(old);
      final stored = jsonDecode(
        (await SharedPreferences.getInstance()).getString(classesKey)!,
      );
      expect(stored.single['start_time'], '13:30');
      expect(stored.single['professor_name'], 'Prof. Cruz');
      final reopened = ScheduleStore();
      await reopened.load();
      expect(reopened.classes.single.toJson(), old.toJson());
    },
  );

  test('class validation follows SQL constraints without requiring mapped rooms or professors', () {
    expect(() => session(reminder: null).validate(), returnsNormally);
    expect(() => session(reminder: 0).validate(), returnsNormally);
    expect(() => session(reminder: 240).validate(), returnsNormally);
    expect(
      () => session(start: '23:00', end: '24:00').validate(),
      returnsNormally,
    );
    for (final invalid in [
      session(subject: '  '),
      session(weekday: 0),
      session(weekday: 8),
      session(start: '08:60'),
      session(start: '25:00'),
      session(start: '09:00', end: '09:00'),
      session(start: '10:00', end: '09:00'),
      session(tz: 'UTC'),
      session(reminder: -1),
      session(reminder: 241),
    ]) {
      expect(invalid.validate, throwsFormatException);
    }
  });

  test('save, import and delete failures leave persisted classes and listeners unchanged', () async {
    final initial = session();
    SharedPreferences.setMockInitialValues({
      classesKey: jsonEncode([initial.toJson()]),
    });
    var fail = true;
    final store = ScheduleStore(
      writeString: (key, value) async {
        if (fail) return false;
        return (await SharedPreferences.getInstance()).setString(key, value);
      },
    );
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);
    await expectLater(
      store.save(session(subject: 'Edited subject')),
      throwsStateError,
    );
    await expectLater(
      store.importClasses([session(id: 'second', subject: 'Math 1')]),
      throwsStateError,
    );
    await expectLater(store.remove(initial.id), throwsStateError);
    expect(store.classes.single.subject, initial.subject);
    expect(notifications, 0);
    final reopened = ScheduleStore();
    await reopened.load();
    expect(reopened.classes.single.subject, initial.subject);
    fail = false;
    await store.save(session(subject: 'Saved edit'));
    expect(store.classes.single.subject, 'Saved edit');
    expect(notifications, 1);
  });

  test('a pending save cannot overwrite another imported meeting', () async {
    final gate = Completer<void>();
    var writes = 0;
    final store = ScheduleStore(
      writeString: (key, value) async {
        if (writes++ == 0) await gate.future;
        return (await SharedPreferences.getInstance()).setString(key, value);
      },
    );
    await store.load();
    final first = store.save(session(id: 'one'));
    final second = store.importClasses([session(id: 'two', subject: 'Math 1')]);
    await Future<void>.delayed(Duration.zero);
    expect(store.classes, isEmpty);
    gate.complete();
    await first;
    await second;
    expect(store.classes.map((c) => c.id), ['one', 'two']);
  });

  test(
    'invalid imports are rejected before writing any part of the batch',
    () async {
      final store = ScheduleStore();
      await store.load();
      await expectLater(
        store.importClasses([session(), session(id: 'bad', weekday: 8)]),
        throwsFormatException,
      );
      expect(store.classes, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(classesKey),
        isNull,
      );
    },
  );
}
