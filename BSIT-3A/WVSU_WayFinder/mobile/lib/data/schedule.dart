import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/time.dart';

/// UUID v4 for class_sessions.id and schedule_uploads.id.
String newScheduleId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class ClassSession {
  const ClassSession({
    required this.id,
    required this.subject,
    required this.weekday,
    required this.start,
    required this.end,
    required this.roomCodeRaw,
    this.roomPlaceId,
    this.professor,
    this.remindMinutes,
    this.uploadId,
    this.tz = 'Asia/Manila',
  });

  final String id;
  final String subject;
  final int weekday; // 1 = Monday ... 7 = Sunday
  final String start;
  final String end;
  final String roomCodeRaw;
  final String? roomPlaceId;
  final String? professor;
  final int? remindMinutes;
  final String? uploadId;
  final String tz;

  /// The column names in 0003_schedule.sql. user_id/updated_at are database
  /// defaults for authenticated writes; local schedules do not invent an owner.
  Map<String, dynamic> toJson() => {
    'id': id,
    'upload_id': uploadId,
    'subject': subject,
    'weekday': weekday,
    'start_time': start,
    'end_time': end,
    'tz': tz,
    'room_code_raw': roomCodeRaw,
    'room_place_id': roomPlaceId,
    'professor_name': professor,
    'remind_minutes': remindMinutes,
  };

  /// Reads SQL-shaped rows and the original camelCase device preferences.
  factory ClassSession.fromJson(Map<String, dynamic> j) {
    dynamic field(String column, String legacy) =>
        j.containsKey(column) ? j[column] : j[legacy];
    final session = ClassSession(
      id: j['id'] as String,
      subject: j['subject'] as String,
      weekday: j['weekday'] as int,
      start: _normaliseClock(field('start_time', 'start') as String),
      end: _normaliseClock(field('end_time', 'end') as String),
      tz: j.containsKey('tz') ? j['tz'] as String : 'Asia/Manila',
      roomCodeRaw: field('room_code_raw', 'roomCodeRaw') as String,
      roomPlaceId: field('room_place_id', 'roomPlaceId') as String?,
      professor: field('professor_name', 'professor') as String?,
      remindMinutes: field('remind_minutes', 'remindMinutes') as int?,
      uploadId: field('upload_id', 'uploadId') as String?,
    );
    session.validate();
    return session;
  }

  /// Mirrors the class_sessions CHECK constraints. A room may be empty or
  /// unconfirmed, and the professor and reminder may be null in the SQL schema.
  void validate() {
    if (subject.trim().isEmpty) {
      throw const FormatException('Enter the subject.');
    }
    if (weekday < 1 || weekday > 7) {
      throw const FormatException('Choose a day from Monday to Sunday.');
    }
    final startValue = _clockMicroseconds(start);
    final endValue = _clockMicroseconds(end);
    if (startValue == null || endValue == null) {
      throw const FormatException('Use a valid class time.');
    }
    if (endValue <= startValue) {
      throw const FormatException('End time must be after start time.');
    }
    if (tz != 'Asia/Manila') {
      throw const FormatException('Class times must use Asia/Manila.');
    }
    if (remindMinutes != null && (remindMinutes! < 0 || remindMinutes! > 240)) {
      throw const FormatException(
        'Reminders must be between 0 and 240 minutes.',
      );
    }
  }

  String get signature =>
      '$weekday|$start|$end|$remindMinutes|$subject|$roomCodeRaw|$professor|$tz';
}

String _normaliseClock(String value) {
  final match = RegExp(r'^(\d{2}:\d{2}):00(?:\.0+)?$').firstMatch(value);
  return match?.group(1) ?? value;
}

int? _clockMicroseconds(String value) {
  final match = RegExp(r'^(\d{2}):([0-5]\d)(?::([0-5]\d)(?:\.(\d{1,6}))?)?$')
      .firstMatch(value);
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final second = int.parse(match[3] ?? '0');
  final fraction = int.parse((match[4] ?? '').padRight(6, '0'));
  if (hour > 24 ||
      (hour == 24 && (minute != 0 || second != 0 || fraction != 0))) {
    return null;
  }
  return ((hour * 60 + minute) * 60 + second) * 1000000 + fraction;
}

/// Device-private persistence, with the same fields as 0003_schedule.sql.
/// Cloud writes still require Supabase Auth; no anonymous cloud sync occurs.
class ScheduleStore extends ChangeNotifier {
  ScheduleStore({
    @visibleForTesting
    Future<bool> Function(String key, String value)? writeString,
  }) : _writeString = writeString;

  static const _classesKey = 'wf.schedule.classes.v1';
  static const _imageKey = 'wf.schedule.image.v1';
  final Future<bool> Function(String key, String value)? _writeString;
  Future<void> _writes = Future<void>.value();
  List<ClassSession> _classes = [];
  String? _imageBase64;
  bool loaded = false;

  List<ClassSession> get classes => List.unmodifiable(_classes);
  String? get imageBase64 => _imageBase64;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _read() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_classesKey);
    final classes = raw == null
        ? <ClassSession>[]
        : (jsonDecode(raw) as List)
              .map(
                (row) => ClassSession.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList();
    _classes = classes;
    _imageBase64 = p.getString(_imageKey);
    loaded = true;
  }

  Future<void> load() => _serialize(() async {
    await _read();
    notifyListeners();
  });

  Future<void> _ensureLoaded() async {
    if (!loaded) await _read();
  }

  Future<void> _commit(List<ClassSession> classes) async {
    for (final session in classes) {
      session.validate();
    }
    final p = await SharedPreferences.getInstance();
    try {
      final encoded = jsonEncode(classes.map((c) => c.toJson()).toList());
      final saved =
          await (_writeString?.call(_classesKey, encoded) ??
              p.setString(_classesKey, encoded));
      if (!saved) throw StateError('Schedule could not be saved');
    } catch (_) {
      // SharedPreferences updates its cache before the platform write completes.
      // Reload it on failure so a later load does not expose an unsaved change.
      if (_writeString == null) {
        try {
          await p.reload();
        } catch (_) {}
      }
      rethrow;
    }
    _classes = classes;
    notifyListeners();
  }

  ClassSession? byId(String id) =>
      _classes.where((c) => c.id == id).firstOrNull;

  Future<void> save(ClassSession c) => _serialize(() async {
    c.validate();
    await _ensureLoaded();
    final next = List<ClassSession>.of(_classes);
    final index = next.indexWhere((x) => x.id == c.id);
    if (index >= 0) {
      next[index] = c;
    } else {
      next.add(c);
    }
    await _commit(next);
  });

  Future<int> importClasses(
    List<ClassSession> incoming,
  ) => _serialize(() async {
    for (final c in incoming) {
      c.validate();
    }
    await _ensureLoaded();
    String key(ClassSession c) =>
        '${c.subject.trim().toLowerCase()}|${c.weekday}|${c.start}|${c.end}|${c.roomCodeRaw.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
    final known = _classes.map(key).toSet();
    final added = incoming.where((c) => known.add(key(c))).toList();
    if (added.isEmpty) return 0;
    await _commit([..._classes, ...added]);
    return added.length;
  });

  Future<void> remove(String id) => _serialize(() async {
    await _ensureLoaded();
    if (!_classes.any((c) => c.id == id)) return;
    await _commit(_classes.where((c) => c.id != id).toList());
  });

  Future<void> setImage(String? base64) => _serialize(() async {
    await _ensureLoaded();
    final p = await SharedPreferences.getInstance();
    try {
      final saved = base64 == null
          ? await p.remove(_imageKey)
          : await p.setString(_imageKey, base64);
      if (!saved) throw StateError('Timetable image could not be saved');
    } catch (_) {
      try {
        await p.reload();
      } catch (_) {}
      rethrow;
    }
    _imageBase64 = base64;
    notifyListeners();
  });
}

class UpcomingClass {
  const UpcomingClass(this.session, this.start, this.end);
  final ClassSession session;
  final DateTime start;
  final DateTime end;
}

UpcomingClass? nextClass(List<ClassSession> classes, DateTime now) {
  UpcomingClass? best;
  for (final s in classes) {
    final o = nextOccurrence(s.weekday, s.start, s.end, now);
    if (best == null || o.start.isBefore(best.start)) {
      best = UpcomingClass(s, o.start, o.end);
    }
  }
  return best;
}

DateTime? nextReminderAt(ClassSession c, DateTime now) {
  final m = c.remindMinutes;
  if (m == null) return null;
  var o = nextOccurrence(c.weekday, c.start, c.end, now);
  var at = o.start.subtract(Duration(minutes: m));
  if (!at.isAfter(now)) {
    o = nextOccurrence(
      c.weekday,
      c.start,
      c.end,
      o.end.add(const Duration(minutes: 1)),
    );
    at = o.start.subtract(Duration(minutes: m));
  }
  return at;
}

typedef TimerFactory = Timer Function(Duration, void Function());

/// One pending reminder per class. `sync` cancels reminders of deleted or changed classes.
/// In-app timers only: background notifications need flutter_local_notifications on a real device.
class ReminderScheduler {
  ReminderScheduler({
    required this.now,
    required this.timer,
    required this.notify,
  });
  final DateTime Function() now;
  final TimerFactory timer;
  final void Function(ClassSession) notify;
  final _pending = <String, ({Timer t, DateTime fireAt, String sig})>{};

  Map<String, DateTime> get pending => {
    for (final e in _pending.entries) e.key: e.value.fireAt,
  };

  void sync(List<ClassSession> classes) {
    final wanted = {for (final c in classes) c.id: c};
    for (final id in _pending.keys.toList()) {
      final c = wanted[id];
      if (c == null || c.signature != _pending[id]!.sig) cancel(id);
    }
    for (final c in classes) {
      if (!_pending.containsKey(c.id)) _schedule(c);
    }
  }

  void _schedule(ClassSession c) {
    final n = now();
    final at = nextReminderAt(c, n);
    if (at == null) return;
    final t = timer(at.difference(n), () {
      _pending.remove(c.id);
      notify(c);
      _schedule(c);
    });
    _pending[c.id] = (t: t, fireAt: at, sig: c.signature);
  }

  void cancel(String id) {
    _pending.remove(id)?.t.cancel();
  }

  void cancelAll() {
    for (final id in _pending.keys.toList()) {
      cancel(id);
    }
  }
}
