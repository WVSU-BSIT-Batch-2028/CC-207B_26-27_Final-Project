import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_shell.dart';
import 'login_screen.dart';

/// Listens to Firebase Auth state and routes users to LoginScreen, PatientShell, or DoctorShell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<UserRole>(
          future: authService.getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data ?? UserRole.patient;
            return role == UserRole.doctor
                ? const DoctorShell()
                : const PatientShell();
          },
        );
      },
    );
  }
}