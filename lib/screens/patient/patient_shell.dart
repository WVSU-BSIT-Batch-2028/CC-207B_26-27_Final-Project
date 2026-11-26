import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../models/appointment.dart';
import '../../models/doctor.dart';
import '../../models/user_role.dart';
import '../../services/guide_service.dart';
import '../../services/live_updates_service.dart';
import '../../services/prescription_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../widgets/h360_bottom_nav.dart';
import '../../widgets/reminder_due_dialog.dart';
import '../ai/ai_assistant_screen.dart';
import '../onboarding/how_to_use_screen.dart';
import '../profile/profile_screen.dart';
import '../records/records_screen.dart';
import 'home/home_screen.dart';
import 'appointments/appointments_screen.dart';
import 'appointments/video_consultation_screen.dart';
import 'appointments/booking/doctor_selection_screen.dart';
import 'appointments/booking/date_time_selection_screen.dart';
import 'appointments/booking/appointment_details_screen.dart';
import 'appointments/booking/appointment_confirmation_screen.dart';
import 'prescriptions/prescriptions_screen.dart';

/// Patient frame with the bottom tabs: Home, Appointment, Prescription,
/// Records, Profile.
class PatientShell extends StatefulWidget {
  const PatientShell({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  /// Bumped when appointments change; the tab reloads quietly.
  int _appointmentsRefreshToken = 0;

  /// Bumped when the Prescriptions tab opens or prescriptions change. Tabs
  /// stay alive in an IndexedStack, so this makes the tab reload quietly.
  int _prescriptionsRefreshToken = 0;

  /// Bumped when records change; the Records tab is rebuilt.
  int _recordsRefreshToken = 0;

  /// Live updates: Firestore changes waiting for the next reload.
  StreamSubscription<LiveTopic>? _liveUpdates;
  final Set<LiveTopic> _changedTopics = {};
  Timer? _reloadSoon;

  void _goTo(int index) {
    if (!mounted) return;

    setState(() {
      // Opening Prescriptions reloads it.
      if (index == 2 && _index != 2) _prescriptionsRefreshToken++;
      // Coming back to Home reloads it quietly.
      if (index == 0 && _index != 0) _homeRefreshToken++;
      _index = index;
    });
  }

  /// Opens the appointment booking flow.
  void _openDoctorSelection() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (doctorContext) {
          return DoctorSelectionScreen(
            onNext: (Doctor doctor) {
              if (!doctorContext.mounted) return;

              Navigator.of(doctorContext).push(
                MaterialPageRoute<void>(
                  builder: (dateTimeContext) {
                    return DateTimeSelectionScreen(
                      doctor: doctor,
                      onNext: (DateTime dateTime) {
                        if (!dateTimeContext.mounted) return;

                        Navigator.of(dateTimeContext).push(
                          MaterialPageRoute<void>(
                            builder: (detailsContext) {
                              return AppointmentDetailsScreen(
                                doctor: doctor,
                                appointmentDateTime: dateTime,
                                onBookNow: (details) {
                                  if (!detailsContext.mounted) return;

                                  Navigator.of(detailsContext).push(
                                    MaterialPageRoute<void>(
                                      builder: (confirmationContext) {
                                        return AppointmentConfirmationScreen(
                                          doctor: doctor,
                                          appointmentDateTime: dateTime,
                                          bookingDetails: details,
                                          onDone: () {
                                            if (!confirmationContext.mounted) {
                                              return;
                                            }

                                            Navigator.of(
                                              confirmationContext,
                                            ).pushNamedAndRemoveUntil(
                                              AppRoutes.patientShell,
                                              (route) => false,
                                              arguments: 1,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Opens the video consultation screen.
  void _openVideoConsultation(Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoConsultationScreen(
          appointment: appointment,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Open on the requested tab.
    _index = widget.initialIndex.clamp(0, 4);

    // New accounts see the "How to use" guide before the dashboard.
    _checkGuide();

    // Medicine reminders are checked while the patient side is open.
    ReminderScheduler.instance.start(this, _onReminderDue);

    // Reload tabs by themselves when the patient's data changes.
    _liveUpdates = LiveUpdatesService.instance.watch(UserRole.patient).listen(_onDataChanged);
  }

  @override
  void dispose() {
    ReminderScheduler.instance.stop(this);
    _liveUpdates?.cancel();
    _reloadSoon?.cancel();
    super.dispose();
  }

  /// Collects changes for 400 ms, then reloads the affected tabs once.
  /// Home always reloads, since it shows a bit of everything.
  void _onDataChanged(LiveTopic topic) {
    _changedTopics.add(topic);
    _reloadSoon?.cancel();
    _reloadSoon = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        if (_changedTopics.contains(LiveTopic.appointments)) _appointmentsRefreshToken++;
        if (_changedTopics.contains(LiveTopic.prescriptions)) _prescriptionsRefreshToken++;
        if (_changedTopics.contains(LiveTopic.records)) _recordsRefreshToken++;
        _homeRefreshToken++;
        _changedTopics.clear();
      });
    });
  }

  /// Due reminders wait here while a popup is already open.
  final List<DueReminder> _dueQueue = [];
  bool _showingReminder = false;

  /// Bumped when Home should reload quietly.
  int _homeRefreshToken = 0;

  /// Shows the popup for a due medicine (one at a time).
  void _onReminderDue(DueReminder reminder) {
    _dueQueue.add(reminder);
    if (!_showingReminder) _showNextReminder();
  }

  Future<void> _showNextReminder() async {
    if (_dueQueue.isEmpty || !mounted) return;
    _showingReminder = true;
    final reminder = _dueQueue.removeAt(0);

    final answer = await showReminderDueDialog(context, reminder);
    if (!mounted) return;

    if (answer == ReminderAnswer.later) {
      ReminderScheduler.instance.snooze(reminder);
    } else if (answer == ReminderAnswer.taken) {
      try {
        await PrescriptionService.instance.setTakenToday(reminder.prescriptionId, true);
        if (mounted) {
          setState(() => _homeRefreshToken++);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${reminder.title} marked as taken.')),
          );
        }
      } on PrescriptionException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    _showingReminder = false;
    _showNextReminder();
  }

  /// null while checking; true = show the guide instead of the dashboard.
  bool? _showGuide;

  /// Decides whether this account still needs the first-time guide.
  Future<void> _checkGuide() async {
    final seen = await GuideService.instance.hasSeen(UserRole.patient);
    if (mounted) setState(() => _showGuide = !seen);
  }

  /// Remembers the guide was seen, then opens the dashboard.
  void _finishGuide() {
    GuideService.instance.markSeen(UserRole.patient);
    setState(() => _showGuide = false);
  }

  /// Opens the AI assistant and handles the action it returns.
  Future<void> _openAssistant() async {
    final action = await Navigator.of(context).pushNamed(
      AppRoutes.assistant,
    );

    if (!mounted) return;

    if (action == AssistantAction.bookAppointment) {
      _goTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking whether this account saw the guide.
    if (_showGuide == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // New account: the guide comes before the dashboard.
    if (_showGuide!) {
      return HowToUseScreen(role: UserRole.patient, onFinished: _finishGuide);
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            refreshToken: _homeRefreshToken,
            onNavigate: _goTo,
            onOpenAssistant: _openAssistant,
          ),
          AppointmentsScreen(
            refreshToken: _appointmentsRefreshToken,
            onBookAppointment: _openDoctorSelection,
            onJoinConsultation: _openVideoConsultation,
          ),
          PrescriptionsScreen(refreshToken: _prescriptionsRefreshToken),
          RecordsScreen(
            key: ValueKey(_recordsRefreshToken),
            onBack: () => _goTo(0),
          ),
          const ProfileScreen(
            role: UserRole.patient,
          ),
        ],
      ),
      bottomNavigationBar: H360BottomNav(
        items: H360BottomNav.patientItems,
        currentIndex: _index,
        onTap: _goTo,
      ),
    );
  }
}
