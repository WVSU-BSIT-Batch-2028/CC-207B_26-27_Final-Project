import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../models/user_role.dart';
import '../../services/guide_service.dart';
import '../../widgets/h360_bottom_nav.dart';
import '../ai/ai_assistant_screen.dart';
import '../onboarding/how_to_use_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/module_placeholder.dart';
import 'home/home_screen.dart';
import 'appointments/appointments_screen.dart';
import '../../models/doctor.dart';
import 'appointments/booking/doctor_selection_screen.dart';
import 'appointments/booking/date_time_selection_screen.dart';
import 'appointments/booking/appointment_details_screen.dart';

/// Patient frame: Home / Appointment / Prescription / Records / Profile.
///
/// IndexedStack keeps each tab alive, so switching tabs never reloads data.
class PatientShell extends StatefulWidget {
  /// Creates the patient navigation shell.
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

/// Manages patient tab navigation and appointment booking navigation.
class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  /// Opens the doctor selection stage of appointment booking.
  Future<void> _openDoctorSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorSelectionScreen(
          onNext: (Doctor doctor) {
            // Open the date and time selection stage.
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DateTimeSelectionScreen(
                  doctor: doctor,
                  onNext: (DateTime dateTime) {
                    // Open the appointment details stage.
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AppointmentDetailsScreen(
                          doctor: doctor,
                          appointmentDateTime: dateTime,
                          onBookNow: (details) {
                            // Display the selected booking options for now.
                            final date = MaterialLocalizations.of(context)
                                .formatMediumDate(dateTime);
                            final time = TimeOfDay.fromDateTime(dateTime)
                                .format(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Selected: $date at $time | '
                                  '${details.consultationType} | '
                                  'Reminder: '
                                  '${details.reminderEnabled ? 'On' : 'Off'}',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Show the "How to use" guide the first time the patient side opens.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showGuideIfFirstTime());
  }

  /// Displays the patient guide when it has not been viewed before.
  Future<void> _showGuideIfFirstTime() async {
    if (await GuideService.instance.hasSeen(UserRole.patient)) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const HowToUseScreen(role: UserRole.patient),
      ),
    );

    await GuideService.instance.markSeen(UserRole.patient);
  }

  /// Changes the currently selected patient tab.
  void _goTo(int index) => setState(() => _index = index);

  /// Opens the AI assistant and handles its requested navigation action.
  Future<void> _openAssistant() async {
    final action = await Navigator.of(context).pushNamed(AppRoutes.assistant);

    if (action == AssistantAction.bookAppointment) {
      _goTo(1);
    }
  }

  /// Builds the patient shell and bottom navigation.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onNavigate: _goTo,
            onOpenAssistant: _openAssistant,
          ),

          // Patient Appointments Overview.
          AppointmentsScreen(
            onBookAppointment: _openDoctorSelection,
          ),

          // TODO(Prescriptions owner): replace with PrescriptionsScreen.
          const ModulePlaceholder(
            title: 'Prescriptions',
            icon: Icons.medication_rounded,
            hint:
                'Prescription list, reminders and refill requests will live here.',
          ),

          // TODO(Records owner): replace with RecordsScreen.
          const ModulePlaceholder(
            title: 'Records',
            icon: Icons.folder_shared_rounded,
            hint: 'Consultations and lab results will live here.',
          ),

          const ProfileScreen(role: UserRole.patient),
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
