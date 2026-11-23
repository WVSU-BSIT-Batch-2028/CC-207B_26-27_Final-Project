import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../models/appointment.dart';
import '../../models/doctor.dart';
import '../../models/user_role.dart';
import '../../services/guide_service.dart';
import '../../widgets/h360_bottom_nav.dart';
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

/// Patient frame: Home / Appointment / Prescription / Records / Profile.
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
  int _appointmentsRefreshToken = 0;

  /// Bumped every time the Prescriptions tab is opened. The tabs live in an
  /// IndexedStack (kept alive), so without this the list would load once and
  /// never show a prescription the doctor added later.
  int _prescriptionsRefreshToken = 0;

  void _goTo(int index) {
    if (!mounted) return;

    setState(() {
      // Opening the Prescriptions tab (index 2) reloads it from Firestore.
      if (index == 2 && _index != 2) _prescriptionsRefreshToken++;
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

                                            debugPrint(
                                              'BOOKING DEBUG: Done button tapped.',
                                            );

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

    // Allows the shell to open directly on a requested tab.
    _index = widget.initialIndex.clamp(0, 4);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showGuideIfFirstTime();
      }
    });
  }

  /// Displays the patient guide when it has not been viewed.
  Future<void> _showGuideIfFirstTime() async {
    final hasSeen = await GuideService.instance.hasSeen(UserRole.patient);

    if (!mounted || hasSeen) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const HowToUseScreen(
          role: UserRole.patient,
        ),
      ),
    );

    await GuideService.instance.markSeen(UserRole.patient);
  }

  /// Opens the AI assistant and handles its requested navigation action.
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
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onNavigate: _goTo,
            onOpenAssistant: _openAssistant,
          ),
          AppointmentsScreen(
            key: ValueKey(_appointmentsRefreshToken),
            onBookAppointment: _openDoctorSelection,
            onJoinConsultation: _openVideoConsultation,
          ),
          PrescriptionsScreen(key: ValueKey(_prescriptionsRefreshToken)),
          RecordsScreen(
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
