import 'package:flutter/material.dart';

import '../../services/doctor_service.dart';
import '../../widgets/coming_soon_sheet.dart';
import '../../widgets/h360_bottom_nav.dart';
import '../profile/help_support_screen.dart';
import '../profile/logout_dialog.dart';
import '../profile/profile_screen.dart';
import '../../models/user_role.dart';
import '../shared/module_placeholder.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_drawer.dart';
import 'doctor_home_screen.dart';

/// Doctor frame: Home / Appointments / Patients / Profile / Menu.
/// The "Menu" tab opens the slide-out drawer instead of changing page.
class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  static const int _menuTab = 4;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  void _goTo(int index) {
    if (index == _menuTab) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    setState(() => _index = index);
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _openDashboard() => _push(DoctorDashboardScreen(onNavigate: _goTo));

  void _onMenuSelected(DoctorMenuItem item) {
    switch (item) {
      case DoctorMenuItem.appointments:
        _goTo(1);
      case DoctorMenuItem.patients:
        _goTo(2);
      case DoctorMenuItem.profile:
        _goTo(3);
      case DoctorMenuItem.prescriptions:
        showComingSoonSheet(context, title: 'Prescriptions');
      case DoctorMenuItem.medicalRecords:
        showComingSoonSheet(context, title: 'Medical Records');
      case DoctorMenuItem.labResults:
        showComingSoonSheet(context, title: 'Lab Results');
      case DoctorMenuItem.dashboard:
        _openDashboard();
      case DoctorMenuItem.help:
        _push(const HelpSupportScreen(role: UserRole.doctor));
      case DoctorMenuItem.logout:
        confirmLogout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: DoctorDrawer(
        doctorName: 'Dr. Santos',
        specialty: DoctorService.specialty,
        onSelect: _onMenuSelected,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DoctorHomeScreen(onNavigate: _goTo, onOpenDashboard: _openDashboard),
          // TODO(Appointments owner): replace with the doctor's AppointmentsScreen.
          const ModulePlaceholder(
            title: 'Appointments',
            icon: Icons.event_note_rounded,
            hint: 'Upcoming and past appointments, patient overview and video consultation will live here.',
          ),
          // TODO(Records/Patients owner): replace with the doctor's PatientsScreen.
          const ModulePlaceholder(
            title: 'Patients',
            icon: Icons.groups_rounded,
            hint: 'Patient list, records, lab results and prescriptions will live here.',
          ),
          const ProfileScreen(role: UserRole.doctor),
        ],
      ),
      bottomNavigationBar: H360BottomNav(
        items: H360BottomNav.doctorItems,
        currentIndex: _index,
        onTap: _goTo,
      ),
    );
  }
}
