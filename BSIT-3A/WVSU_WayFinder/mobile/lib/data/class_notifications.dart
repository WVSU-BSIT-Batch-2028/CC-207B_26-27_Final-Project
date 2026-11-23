import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/time.dart';
import 'schedule.dart';

const _payloadPrefix = 'wayfinder:class:';

/// The small native boundary also lets scheduling be tested without a phone.
abstract class ClassNotificationBackend {
  bool get supported;
  Future<void> initialize();
  Future<bool> isEnabled();
  Future<bool> requestPermission();
  Future<bool> exactAlarmsAllowed({bool request = false});
  Future<Map<int, String?>> pending();
  Future<void> cancel(int id);
  Future<void> schedule(ClassReminder reminder, {required bool exact});
}

class ClassReminder {
  const ClassReminder({
    required this.id,
    required this.session,
    required this.at,
  });
  final int id;
  final ClassSession session;
  final DateTime at;
  String get payload => '$_payloadPrefix${session.id}';
  String get title => 'Class in ${session.remindMinutes} minutes';
  String get body =>
      '${session.subject} at ${formatClock(session.start)}'
      ' · ${session.roomCodeRaw.isEmpty ? 'Room not specified' : 'Room ${session.roomCodeRaw}'}'
      '${session.professor?.trim().isNotEmpty == true ? ' · ${session.professor}' : ''}';
}

/// One native weekly notification per class. Native alarms remain scheduled
/// when the app closes; the Android boot receiver restores them after reboot.
class ClassNotifications extends ChangeNotifier {
  ClassNotifications({
    ClassNotificationBackend? backend,
    DateTime Function()? now,
  }) : _backend = backend ?? LocalClassNotificationBackend(),
       _now = now ?? DateTime.now;

  final ClassNotificationBackend _backend;
  final DateTime Function() _now;
  Future<void>? _initializing;
  Future<void> _queue = Future<void>.value();
  List<ClassSession> _classes = const [];
  bool _disposed = false;
  bool _initialized = false;
  bool enabled = false;
  bool exact = false;
  int scheduledCount = 0;
  String? error;
  int _omitted = 0;

  bool get supported => _backend.supported;
  String get statusText {
    if (!supported) {
      return 'Phone notifications are available on Android and iOS. Reminders appear while this app is open here.';
    }
    if (error != null) return error!;
    if (!enabled) {
      return 'Enable notifications to get a reminder before each class, even when WayFinder is closed. If permission was denied, allow notifications in your phone settings.';
    }
    final timing = exact
        ? ''
        : ' Android may delay reminders unless exact alarm access is allowed.';
    final limit = _omitted == 0
        ? ''
        : ' $_omitted additional reminders exceed the phone limit of 64; turn some reminders off.';
    return '$scheduledCount weekly class reminders scheduled in Asia/Manila time.$timing$limit';
  }

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    if (!supported) return;
    try {
      await _backend.initialize();
      _initialized = true;
      enabled = await _backend.isEnabled();
      exact = await _backend.exactAlarmsAllowed();
    } on MissingPluginException {
      error =
          'Phone notifications need a full app restart after installation. Your classes are saved.';
    } catch (_) {
      error =
          'Notifications could not be initialized. Your classes are saved; try enabling reminders again.';
    }
    _changed();
  }

  /// Call only from an explicit user action. Startup never requests permission.
  Future<void> enable() => _enqueue(() async {
    await initialize();
    if (!supported || !_initialized) return;
    enabled = await _backend.requestPermission();
    if (enabled) exact = await _backend.exactAlarmsAllowed(request: true);
    await _sync();
  });

  Future<void> sync(List<ClassSession> classes) {
    // A snapshot prevents mutations while asynchronous native calls are pending.
    _classes = List<ClassSession>.of(classes);
    return _enqueue(_sync);
  }

  Future<void> _sync() async {
    await initialize();
    if (!supported || !_initialized) return;
    error = null;
    enabled = await _backend.isEnabled();
    exact = await _backend.exactAlarmsAllowed();
    final plans = buildClassReminders(_classes, _now());
    _omitted = plans.length > 64 ? plans.length - 64 : 0;
    final desired = enabled ? plans.take(64).toList() : <ClassReminder>[];
    final ids = desired.map((r) => r.id).toSet();
    final pending = await _backend.pending();
    for (final entry in pending.entries) {
      // Keep notifications created by unrelated features intact.
      if (entry.value?.startsWith(_payloadPrefix) == true &&
          !ids.contains(entry.key)) {
        await _backend.cancel(entry.key);
      }
    }
    scheduledCount = 0;
    for (final reminder in desired) {
      // Replacing an existing ID refreshes changed room/professor/time text too.
      await _backend.schedule(reminder, exact: exact);
      scheduledCount++;
    }
    _changed();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) async {
      try {
        await action();
      } catch (_) {
        error =
            'Some reminders could not be scheduled. Your classes are saved; check notification permissions and try again.';
        _changed();
      }
    });
    _queue = next;
    return next;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Do not cancel native alarms: they must survive closing WayFinder.
    super.dispose();
  }
}

/// A deterministic hash, rather than String.hashCode (not stable across runs).
int _stableId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

List<ClassReminder> buildClassReminders(
  List<ClassSession> classes,
  DateTime now,
) {
  final used = <int>{};
  final reminders = <ClassReminder>[];
  for (final session
      in classes.toList()..sort((a, b) => a.id.compareTo(b.id))) {
    final at = nextReminderAt(session, now);
    if (at == null) continue;
    var id = _stableId(session.id);
    while (!used.add(id)) {
      id = (id + 1) & 0x7fffffff;
    }
    reminders.add(ClassReminder(id: id, session: session, at: at));
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  return reminders;
}

class LocalClassNotificationBackend implements ClassNotificationBackend {
  LocalClassNotificationBackend({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_class_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> isEnabled() async =>
      defaultTargetPlatform == TargetPlatform.android
      ? await _android?.areNotificationsEnabled() ?? false
      : (await _ios?.checkPermissions())?.isEnabled ?? false;

  @override
  Future<bool> requestPermission() async =>
      defaultTargetPlatform == TargetPlatform.android
      ? await _android?.requestNotificationsPermission() ?? false
      : await _ios?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;

  @override
  Future<bool> exactAlarmsAllowed({bool request = false}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    if (request && await _android?.canScheduleExactNotifications() != true) {
      await _android?.requestExactAlarmsPermission();
    }
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<Map<int, String?>> pending() async => {
    for (final request in await _plugin.pendingNotificationRequests())
      request.id: request.payload,
  };

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> schedule(ClassReminder reminder, {required bool exact}) =>
      _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.at, tz.getLocation('Asia/Manila')),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'wayfinder_classes_v1',
            'Class reminders',
            channelDescription: 'Reminders before your weekly classes',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_class_reminder',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: reminder.payload,
      );
}
