import 'package:flutter/material.dart';

import '../../screens/ai/ai_assistant_screen.dart';
import '../../screens/doctor/doctor_shell.dart';
import '../../screens/patient/patient_shell.dart';
import '../../screens/role/role_select_screen.dart';

/// Named routes + page transitions. Add new full-screen routes here.
class AppRoutes {
  AppRoutes._();

  static const String roleGate = '/'; // temporary: pick patient or doctor
  static const String patientShell = '/patient';
  static const String doctorShell = '/doctor';
  static const String assistant = '/assistant';

  /// Where the app starts. Skip the role gate while developing:
  ///   flutter run -d chrome --dart-define=START_ROUTE=/doctor
  static const String initialRoute =
      String.fromEnvironment('START_ROUTE', defaultValue: roleGate);

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case patientShell:
        return _fade(const PatientShell(), settings);
      case doctorShell:
        return _fade(const DoctorShell(), settings);
      case assistant:
        return _slideUp(const AiAssistantScreen(), settings);
      case roleGate:
      default:
        return _fade(const RoleSelectScreen(), settings);
    }
  }

  static Route<dynamic> _fade(Widget page, RouteSettings settings) =>
      PageRouteBuilder<dynamic>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondary) => page,
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  static Route<dynamic> _slideUp(Widget page, RouteSettings settings) =>
      PageRouteBuilder<dynamic>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondary) => page,
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
}
