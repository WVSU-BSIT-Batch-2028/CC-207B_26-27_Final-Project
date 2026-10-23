import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../models/user_role.dart';
import '../../widgets/h360_bottom_nav.dart';
import '../ai/ai_assistant_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/module_placeholder.dart';
import 'home/home_screen.dart';

/// Patient frame: Home / Appointment / Prescription / Records / Profile.
/// IndexedStack keeps each tab alive, so switching tabs never reloads data.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  Future<void> _openAssistant() async {
    // No type argument on purpose: the named route is a Route<dynamic>, and
    // pushNamed<AssistantAction> would throw a type-cast error (button did nothing).
    final action = await Navigator.of(context).pushNamed(AppRoutes.assistant);
    if (action == AssistantAction.bookAppointment) _goTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onNavigate: _goTo, onOpenAssistant: _openAssistant),
          // TODO(Appointments owner): replace with AppointmentsScreen.
          const ModulePlaceholder(
            title: 'Appointments',
            icon: Icons.event_note_rounded,
            hint: 'Booking, details and video consultation will live here.',
          ),
          // TODO(Prescriptions owner): replace with PrescriptionsScreen.
          const ModulePlaceholder(
            title: 'Prescriptions',
            icon: Icons.medication_rounded,
            hint: 'Prescription list, reminders and refill requests will live here.',
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
