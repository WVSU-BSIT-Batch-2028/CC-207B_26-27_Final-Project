import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/time.dart';

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
  });

  final String id;
  final String subject;
  final int weekday; // 1 = Monday ... 7 = Sunday, Asia/Manila
  final String start; // "HH:MM"
  final String end;
  final String roomCodeRaw; // exactly what the student typed
  final String? roomPlaceId; // null = Room location unconfirmed
  final String? professor;
  final int? remindMinutes; // null = no reminder

  Map<String, dynamic> toJson() => {
        'id': id, 'subject': subject, 'weekday': weekday, 'start': start, 'end': end, 'roomCodeRaw': roomCodeRaw,
        'roomPlaceId': roomPlaceId, 'professor': professor, 'remindMinutes': remindMinutes,
      };

  factory ClassSession.fromJson(Map<String, dynamic> j) => ClassSession(
        id: j['id'] as String, subject: j['subject'] as String, weekday: j['weekday'] as int,
        start: j['start'] as String, end: j['end'] as String, roomCodeRaw: j['roomCodeRaw'] as String,
        roomPlaceId: j['roomPlaceId'] as String?, professor: j['professor'] as String?, remindMinutes: j['remindMinutes'] as int?,
      );

  String get signature => '$weekday|$start|$end|$remindMinutes|$subject|$roomCodeRaw|$professor';
}

/// Private schedule kept on THIS device (shared_preferences). Nothing is sent to a server.
/// Cloud sync needs Supabase Auth + supabase/migrations/0003_schedule.sql (not wired yet).
class ScheduleStore extends ChangeNotifier {
  static const _classesKey = 'wf.schedule.classes.v1';
  static const _imageKey = 'wf.schedule.image.v1';

  List<ClassSession> _classes = [];
  String? _imageBase64;
  bool loaded = false;

  List<ClassSession> get classes => List.unmodifiable(_classes);
  String? get imageBase64 => _imageBase64;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_classesKey);
    _classes = raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(ClassSession.fromJson).toList();
    _imageBase64 = p.getString(_imageKey);
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_classesKey, jsonEncode(_classes.map((c) => c.toJson()).toList()));
  }

  ClassSession? byId(String id) => _classes.where((c) => c.id == id).firstOrNull;

  Future<void> save(ClassSession c) async {
    final i = _classes.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _classes[i] = c;
    } else {
      _classes.add(c);
    }
    notifyListeners();
    await _persist();
  }

  /// Adds reviewed meetings in one write, skipping existing or repeated rows.
  Future<int> importClasses(List<ClassSession> incoming) async {
    String key(ClassSession c) => '${c.subject.trim().toLowerCase()}|${c.weekday}|${c.start}|${c.end}|${c.roomCodeRaw.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
    final known = _classes.map(key).toSet();
    final added = incoming.where((c) => known.add(key(c))).toList();
    if (added.isEmpty) return 0;
    final merged = [..._classes, ...added];
    final p = await SharedPreferences.getInstance();
    final saved = await p.setString(_classesKey, jsonEncode(merged.map((c) => c.toJson()).toList()));
    if (!saved) throw StateError('Schedule could not be saved');
    _classes = merged;
    notifyListeners();
    return added.length;
  }

  Future<void> remove(String id) async {
    _classes.removeWhere((c) => c.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> setImage(String? base64) async {
    _imageBase64 = base64;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (base64 == null) {
      await p.remove(_imageKey);
    } else {
      await p.setString(_imageKey, base64);
    }
  }
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
    if (best == null || o.start.isBefore(best.start)) best = UpcomingClass(s, o.start, o.end);
  }
  return best;
}

DateTime? nextReminderAt(ClassSession c, DateTime now) {
  final m = c.remindMinutes;
  if (m == null) return null;
  var o = nextOccurrence(c.weekday, c.start, c.end, now);
  var at = o.start.subtract(Duration(minutes: m));
  if (!at.isAfter(now)) {
    o = nextOccurrence(c.weekday, c.start, c.end, o.end.add(const Duration(minutes: 1)));
    at = o.start.subtract(Duration(minutes: m));
  }
  return at;
}

typedef TimerFactory = Timer Function(Duration, void Function());

/// One pending reminder per class. `sync` cancels reminders of deleted or changed classes.
/// In-app timers only: background notifications need flutter_local_notifications on a real device.
class ReminderScheduler {
  ReminderScheduler({required this.now, required this.timer, required this.notify});
  final DateTime Function() now;
  final TimerFactory timer;
  final void Function(ClassSession) notify;
  final _pending = <String, ({Timer t, DateTime fireAt, String sig})>{};

  Map<String, DateTime> get pending => {for (final e in _pending.entries) e.key: e.value.fireAt};

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
