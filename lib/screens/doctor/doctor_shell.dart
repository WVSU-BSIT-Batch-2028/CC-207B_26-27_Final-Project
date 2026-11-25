import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/booking_doctor_service.dart';
import '../../services/doctor_service.dart';
import '../../services/profile_service.dart';
import '../../services/guide_service.dart';
import '../../widgets/h360_bottom_nav.dart';
import '../profile/help_support_screen.dart';
import '../profile/logout_dialog.dart';
import '../profile/profile_screen.dart';
import '../../models/user_role.dart';
import '../onboarding/how_to_use_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_drawer.dart';
import 'doctor_home_screen.dart';
import 'doctor_prescriptions_screen.dart';
import 'patients/patients_tab.dart';
import 'appointments/doctor_appointments_screen.dart';

/// Doctor frame with the bottom tabs; Menu opens the drawer.
class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  static const int _menuTab = 4;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  /// Drawer header; replaced by the doctor's name once loaded.
  String _drawerName = 'Doctor';
  String _drawerSpecialty = DoctorService.specialty;

  @override
  void initState() {
    super.initState();
    _loadDrawerHeader();
    // New accounts see the "How to use" guide before the dashboard.
    _checkGuide();
  }

  /// Loads the doctor's name and specialty for the drawer (cached profile).
  Future<void> _loadDrawerHeader() async {
    try {
      final profile = await ProfileService.instance.load(UserRole.doctor);
      final auth = AuthService();
      final user = auth.currentUser;
      final account = user == null ? null : await auth.getUserProfile(user.uid);
      final specialty = user == null || account == null
          ? DoctorService.specialty
          : BookingDoctorService.instance.doctorFrom(user.uid, account).specialty;
      if (!mounted) return;
      setState(() {
        if (profile.fullName.trim().isNotEmpty) _drawerName = profile.fullName;
        _drawerSpecialty = specialty;
      });
    } catch (_) {
      // Keep the defaults.
    }
  }

  /// null while checking; true = show the guide instead of the dashboard.
  bool? _showGuide;

  /// Decides whether this account still needs the first-time guide.
  Future<void> _checkGuide() async {
    final seen = await GuideService.instance.hasSeen(UserRole.doctor);
    if (mounted) setState(() => _showGuide = !seen);
  }

  /// Remembers the guide was seen, then opens the dashboard.
  void _finishGuide() {
    GuideService.instance.markSeen(UserRole.doctor);
    setState(() => _showGuide = false);
  }

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
        _push(const DoctorPrescriptionsScreen());
      // Records and lab results open per patient, from the Patients tab.
      case DoctorMenuItem.medicalRecords:
        _goTo(2);
      case DoctorMenuItem.labResults:
        _goTo(2);
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
    // Still checking whether this account saw the guide.
    if (_showGuide == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // New account: the guide comes before the dashboard.
    if (_showGuide!) {
      return HowToUseScreen(role: UserRole.doctor, onFinished: _finishGuide);
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: DoctorDrawer(
        doctorName: _drawerName,
        specialty: _drawerSpecialty,
        onSelect: _onMenuSelected,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DoctorHomeScreen(onNavigate: _goTo, onOpenDashboard: _openDashboard),
          const DoctorAppointmentsScreen(),
          // Back arrow returns to Home.
          DoctorPatientsTab(onBack: () => _goTo(0)),
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
