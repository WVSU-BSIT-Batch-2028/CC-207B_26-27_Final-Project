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
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;
  int _appointmentsRefreshToken = 0;

  void _goTo(int index) {
    if (!mounted) return;

    setState(() {
      _index = index;
    });
  }

  /// Returns to the Patient Shell after booking confirmation.
  /// Refreshes the Appointments screen to retrieve the latest records.
  void _finishBooking(
    NavigatorState navigator,
    Route<dynamic>? patientRoute,
  ) {
    if (!mounted || !navigator.mounted || patientRoute == null) return;

    navigator.popUntil(
      (route) => identical(route, patientRoute),
    );

    if (!mounted) return;

    setState(() {
      _index = 1;
      _appointmentsRefreshToken++;
    });
  }

  /// Opens the appointment booking flow.
  void _openDoctorSelection() {
    // Capture the actual Patient Shell route.
    final patientRoute = ModalRoute.of(context);

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

                                            _finishBooking(
                                              Navigator.of(
                                                confirmationContext,
                                              ),
                                              patientRoute,
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
          const PrescriptionsScreen(),
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
