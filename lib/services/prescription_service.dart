import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_format.dart';
import '../models/prescription.dart';
import '../models/refill_request.dart';
import '../models/reminder_setting.dart';
import '../models/taken_history.dart';
import 'dashboard_service.dart';

/// Error shown to the user when prescriptions cannot be loaded.
class PrescriptionException implements Exception {
  const PrescriptionException(this.message);

  final String message;
}

/// What has happened with one prescription (used by Prescription Details):
/// was it marked as taken today, and is there a refill request?
class PrescriptionActivity {
  const PrescriptionActivity({required this.takenToday, this.refillRequest});

  final bool takenToday;
  final RefillRequest? refillRequest;
}

/// Gives the patient Prescriptions screens their data.
///
/// For now this is a MOCK: it keeps sample prescriptions in memory and waits
/// a moment to imitate a network call, so the loading state can be seen.
/// When the backend (Firebase / MySQL) is ready, replace the body of
/// [fetchPrescriptions]. Keep the method signature so screens do not change.
class PrescriptionService {
  PrescriptionService._();

  /// One shared instance used by every Prescriptions screen.
  static final PrescriptionService instance = PrescriptionService._();

  /// Sample data is built once and kept in memory, so later screens
  /// (refill request, add prescription) can change the same list.
  late final List<Prescription> _prescriptions = _buildSamples();

  /// Returns every prescription (active and past).
  ///
  /// Follows the demo scenario switch (long-press the avatar on Home):
  /// normal -> sample data, empty -> no prescriptions, error -> throws.
  Future<List<Prescription>> fetchPrescriptions() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const PrescriptionException(
          "We couldn't load your prescriptions. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const <Prescription>[];
      case DemoScenario.normal:
        return List.unmodifiable(_prescriptions);
    }
  }

  /// Refill requests made during this app session (one per prescription id).
  final Map<String, RefillRequest> _refillRequests = {};

  /// Same storage key that `DashboardService.setDoseTaken` writes
  /// ("taken_doses_<date>"). Keep the two in sync: the "Mark as Taken"
  /// history is built on this one store instead of a second one.
  static const String _takenKeyPrefix = 'taken_doses_';

  /// Waits like a network call would, and throws in the "error" demo scenario.
  Future<void> _simulateNetwork([int milliseconds = 500]) async {
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const PrescriptionException(
        "We couldn't reach the server. Check your connection and try again.",
      );
    }
  }

  /// Loads the taken-today flag and refill request for one prescription.
  Future<PrescriptionActivity> fetchActivity(String prescriptionId) async {
    await _simulateNetwork();

    final prefs = await SharedPreferences.getInstance();
    final key = '$_takenKeyPrefix${dateKey(DateTime.now())}';
    final takenIds = prefs.getStringList(key) ?? const <String>[];

    return PrescriptionActivity(
      takenToday: takenIds.contains(prescriptionId),
      refillRequest: _refillRequests[prescriptionId],
    );
  }

  /// Saves (or undoes) "taken today" for a prescription.
  /// Delegates to DashboardService so the data lands in the existing store.
  Future<void> setTakenToday(String prescriptionId, bool taken) async {
    await _simulateNetwork(300);
    await DashboardService.instance.setDoseTaken(prescriptionId, taken);
  }

  /// Sends a refill request. It starts as pending until the doctor answers
  /// (answering is part of the doctor side, which is built by another member).
  ///
  /// Throws [PrescriptionException] if the refill is not available yet or a
  /// request is already waiting, so the rule is enforced here and not only
  /// by the disabled button.
  Future<RefillRequest> requestRefill(String prescriptionId) async {
    await _simulateNetwork(700);

    final prescription =
        _prescriptions.firstWhere((p) => p.id == prescriptionId);

    if (!prescription.isRefillAvailableOn(DateTime.now())) {
      throw const PrescriptionException('This refill is not available yet.');
    }
    if (_refillRequests[prescriptionId]?.status == RefillStatus.pending) {
      throw const PrescriptionException(
        'You already have a refill request waiting for review.',
      );
    }

    final request = RefillRequest(
      prescriptionId: prescriptionId,
      requestedAt: DateTime.now(),
    );
    _refillRequests[prescriptionId] = request;
    return request;
  }

  /// Storage key for one prescription's reminder ("prescription_reminder_rx-1").
  static const String _reminderKeyPrefix = 'prescription_reminder_';

  /// Loads the saved reminder for a prescription, or null if there is none.
  /// Damaged saved data is treated as "no reminder" instead of crashing.
  Future<ReminderSetting?> fetchReminder(String prescriptionId) async {
    await _simulateNetwork(400);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_reminderKeyPrefix$prescriptionId');
    if (raw == null) return null;

    try {
      return ReminderSetting.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves the reminder (replaces any earlier one for the same prescription).
  ///
  /// NOTE: this only stores the settings. Real phone notifications need a
  /// package such as flutter_local_notifications (not added yet).
  Future<void> saveReminder(ReminderSetting reminder) async {
    await _simulateNetwork(600);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_reminderKeyPrefix${reminder.prescriptionId}',
      jsonEncode(reminder.toJson()),
    );
  }

  /// Loads the days on which a prescription was marked as taken.
  ///
  /// Real data: every "taken_doses_<date>" entry (written by Mark as Taken)
  /// that contains this prescription's id. MOCK data: finished prescriptions
  /// also get sample taken days (every day except each 6th) so the history
  /// screen has something to show in the demo.
  Future<TakenHistory> fetchTakenHistory(String prescriptionId) async {
    await _simulateNetwork();

    final matches = _prescriptions.where((p) => p.id == prescriptionId);
    if (matches.isEmpty) {
      throw const PrescriptionException('We could not find this prescription.');
    }
    final prescription = matches.first;

    // dateKey -> date, so the same day is never counted twice.
    final found = <String, DateTime>{};

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_takenKeyPrefix)) continue;
      final ids = prefs.getStringList(key) ?? const <String>[];
      if (!ids.contains(prescriptionId)) continue;

      final parsed = DateTime.tryParse(key.substring(_takenKeyPrefix.length));
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      found[dateKey(day)] = day;
    }

    // MOCK: sample taken days for finished prescriptions only.
    if (!prescription.isActiveOn(DateTime.now())) {
      final start = prescription.startDate;
      for (var i = 0; i < prescription.durationDays; i++) {
        if (i % 6 == 5) continue; // pretend a dose was missed now and then
        final day = DateTime(start.year, start.month, start.day + i);
        found[dateKey(day)] = day;
      }
    }

    // Keep only days inside the course, newest first.
    final startDay = DateTime(
      prescription.startDate.year,
      prescription.startDate.month,
      prescription.startDate.day,
    );
    final days = found.values
        .where(
          (d) => !d.isBefore(startDay) && !d.isAfter(prescription.lastDay),
        )
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return TakenHistory(days);
  }

  /// Sample prescriptions. Dates are relative to today, so the "Active"
  /// and "History" tabs always look right when the app is demoed.
  List<Prescription> _buildSamples() {
    final now = DateTime.now();
    DateTime daysFromNow(int days) =>
        DateTime(now.year, now.month, now.day + days);

    return [
      // Active
      Prescription(
        id: 'rx-1',
        medicineName: 'Amoxicillin',
        strength: '500mg',
        form: 'Capsule',
        instruction: 'Take 1 capsule - 2x a day',
        durationDays: 7,
        startDate: daysFromNow(-1),
        prescribedBy: 'Dr. Maria Santos',
        doctorPhone: '09123456789',
        prescribedOn: daysFromNow(-1),
        refillDate: daysFromNow(0), // available today: lets you demo a refill request
        notes: 'Take after meals. Finish the full course.',
      ),
      Prescription(
        id: 'rx-2',
        medicineName: 'Paracetamol',
        strength: '500mg',
        form: 'Tablet',
        instruction: 'Take 1 tablet - 4x a day',
        durationDays: 14,
        startDate: daysFromNow(-3),
        prescribedBy: 'Dr. Maria Santos',
        doctorPhone: '09123456789',
        prescribedOn: daysFromNow(-3),
        refillDate: daysFromNow(11),
      ),
      Prescription(
        id: 'rx-3',
        medicineName: 'Cetirizine',
        strength: '10mg',
        form: 'Tablet',
        instruction: 'Take 1 tablet - 1x a day',
        durationDays: 60,
        startDate: daysFromNow(-10),
        prescribedBy: 'Dr. Maria Santos',
        doctorPhone: '09123456789',
        prescribedOn: daysFromNow(-10),
        refillDate: daysFromNow(50),
        notes: 'Take at night. May cause drowsiness.',
      ),

      // History (treatment already finished)
      Prescription(
        id: 'rx-4',
        medicineName: 'Amlodipine',
        strength: '5mg',
        form: 'Capsule',
        instruction: 'Take 1 capsule - 2x a day',
        durationDays: 30,
        startDate: daysFromNow(-75),
        prescribedBy: 'Dr. Jon Doe',
        doctorPhone: '09123456789',
        prescribedOn: daysFromNow(-75),
        lastRefill: daysFromNow(-50),
      ),
      Prescription(
        id: 'rx-5',
        medicineName: 'Mefenamic Acid',
        strength: '500mg',
        form: 'Capsule',
        instruction: 'Take 1 capsule - 3x a day',
        durationDays: 5,
        startDate: daysFromNow(-60),
        prescribedBy: 'Dr. Maria Santos',
        doctorPhone: '09123456789',
        prescribedOn: daysFromNow(-60),
      ),
    ];
  }
}
