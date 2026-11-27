import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wvsu_wayfinder/data/class_notifications.dart';
import 'package:wvsu_wayfinder/data/schedule.dart';

ClassSession session({
  String id = 'math',
  String room = 'CB 203',
  String professor = 'Prof. Santos',
  int day = 1,
  String start = '13:30',
  String end = '15:00',
  int? minutes = 15,
}) => ClassSession(
  id: id,
  subject: 'Math 1',
  weekday: day,
  start: start,
  end: end,
  roomCodeRaw: room,
  professor: professor,
  remindMinutes: minutes,
);

class FakeBackend implements ClassNotificationBackend {
  @override
  bool supported = true;
  bool permission = true;
  bool exact = true;
  int permissionRequests = 0;
  int exactRequests = 0;
  final requests = <int, String?>{};
  final scheduled = <ClassReminder>[];
  final cancelled = <int>[];
  Completer<void>? holdSchedule;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isEnabled() async => permission;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<bool> exactAlarmsAllowed({bool request = false}) async {
    if (request) exactRequests++;
    return exact;
  }

  @override
  Future<Map<int, String?>> pending() async => Map.of(requests);
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    requests.remove(id);
  }

  @override
  Future<void> schedule(ClassReminder reminder, {required bool exact}) async {
    final hold = holdSchedule;
    holdSchedule = null;
    await hold?.future;
    scheduled.add(reminder);
    requests[reminder.id] = reminder.payload;
  }
}

void main() {
  final monday = DateTime.utc(2026, 11, 23, 0);

  test(
    'weekly reminder uses Manila time, with room and professor in its text',
    () {
      final reminder = buildClassReminders([session()], monday).single;
      expect(reminder.at, DateTime.utc(2026, 11, 23, 5, 15));
      expect(reminder.title, 'Class in 15 minutes');
      expect(reminder.body, contains('1:30 PM · Room CB 203 · Prof. Santos'));
    },
  );

  test('a Monday midnight class has its reminder on Sunday', () {
    final reminder = buildClassReminders([
      session(start: '00:05', end: '01:00'),
    ], DateTime.utc(2026, 11, 22, 15, 30)).single;
    expect(reminder.at, DateTime.utc(2026, 11, 22, 15, 50));
  });

  test('reminders whose lead time has passed move to next week', () {
    final reminder = buildClassReminders([
      session(),
    ], DateTime.utc(2026, 11, 23, 5, 20)).single;
    expect(reminder.at, DateTime.utc(2026, 11, 30, 5, 15));
  });

  test(
    'reopening uses stable IDs and professor edits refresh notification text',
    () async {
      final backend = FakeBackend();
      final service = ClassNotifications(backend: backend, now: () => monday);
      await service.sync([session()]);
      final id = backend.scheduled.single.id;
      final reopened = ClassNotifications(backend: backend, now: () => monday);
      await reopened.sync([session(professor: 'Prof. Cruz')]);
      expect(backend.scheduled.last.id, id);
      expect(backend.scheduled.last.body, contains('Prof. Cruz'));
      expect(backend.requests, hasLength(1));
      service.dispose();
      reopened.dispose();
    },
  );

  test(
    'deletion and disabling a class cancel native alarms after reopening',
    () async {
      final backend = FakeBackend();
      final service = ClassNotifications(backend: backend, now: () => monday);
      await service.sync([session(), session(id: 'english')]);
      backend.requests[99] = 'unrelated-feature';
      final reopened = ClassNotifications(backend: backend, now: () => monday);
      await reopened.sync([session(minutes: null)]);
      expect(backend.cancelled, hasLength(2));
      expect(backend.requests, {99: 'unrelated-feature'});
      service.dispose();
      reopened.dispose();
    },
  );

  test(
    'startup never requests permission; denial stays visible and cancels stale alarms',
    () async {
      final backend = FakeBackend()..permission = false;
      backend.requests[7] = 'wayfinder:class:old';
      final service = ClassNotifications(backend: backend, now: () => monday);
      await service.sync([session()]);
      expect(backend.permissionRequests, 0);
      expect(service.enabled, false);
      expect(service.statusText, contains('phone settings'));
      expect(backend.requests, isEmpty);
      await service.enable();
      expect(backend.permissionRequests, 1);
      expect(backend.exactRequests, 0);
      expect(backend.scheduled, isEmpty);
      service.dispose();
    },
  );

  test(
    'missing exact access reports possible delay without losing reminders',
    () async {
      final backend = FakeBackend()..exact = false;
      final service = ClassNotifications(backend: backend, now: () => monday);
      await service.sync([session()]);
      expect(service.scheduledCount, 1);
      expect(service.statusText, contains('may delay'));
      service.dispose();
    },
  );

  test(
    'serial native writes finish before deletion cancels their alarms',
    () async {
      final backend = FakeBackend();
      final gate = Completer<void>();
      backend.holdSchedule = gate;
      final service = ClassNotifications(backend: backend, now: () => monday);
      final add = service.sync([session()]);
      await Future<void>.delayed(Duration.zero);
      final remove = service.sync([]);
      gate.complete();
      await Future.wait([add, remove]);
      expect(backend.requests, isEmpty);
      expect(service.scheduledCount, 0);
      service.dispose();
    },
  );
}
