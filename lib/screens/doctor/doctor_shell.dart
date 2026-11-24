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

  /// Shown at the top of the drawer; replaced by the signed-in doctor's
  /// name and specialty once they load.
  String _drawerName = 'Doctor';
  String _drawerSpecialty = DoctorService.specialty;

  @override
  void initState() {
    super.initState();
    _loadDrawerHeader();
    // New accounts see the "How to use" guide before the dashboard.
    _checkGuide();
  }

  /// Reads the doctor's name and specialty for the drawer (from the cached
  /// `users/{uid}` document, so no extra Firestore read). If it fails, the defaults stay.
  Future<void> _loadDrawerHeader() async {
    try {
      final profile = await ProfileService.instance.load(UserRole.doctor);
      final auth = AuthService();
      final user = auth.currentUser;
      // The `users/{uid}` document is already cached by the profile load.
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

  /// "Get started" or "Skip" on the guide: remember it, open the dashboard.
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
      // Records and lab results are opened per patient, from the Patients tab.
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
    // Checking whether this account saw the guide (a moment on first load).
    if (_showGuide == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // A new account: the step-by-step guide comes before the dashboard.
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
          // Replaced with the doctor's AppointmentsScreen.
          const DoctorAppointmentsScreen(),
          // Patients tab (Gian). Back arrow returns to Home.
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
