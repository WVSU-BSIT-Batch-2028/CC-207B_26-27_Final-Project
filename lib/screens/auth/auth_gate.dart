
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../widgets/state_views.dart';
import '../doctor/doctor_shell.dart';
import '../patient/patient_shell.dart';
import 'login_screen.dart';

/// Listens to Firebase Auth state and routes users to LoginScreen,
/// PatientShell, or DoctorShell.
///
/// Caches the Firestore role lookup per UID so widget rebuilds
/// do not cause unnecessary reads.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  String? _cachedUid;
  Future<UserRole>? _roleFuture;

  /// Retries briefly if the user profile is still being written
  /// to Firestore immediately after account creation.
  Future<UserRole> _fetchRoleWithRetry(String uid) async {
    const maxAttempts = 5;
    const retryDelay = Duration(milliseconds: 350);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _authService.getUserRole(uid);
      } catch (e) {
        final isMissingProfile =
            e.toString().contains('User profile not found');

        if (!isMissingProfile || attempt == maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(retryDelay);
      }
    }

    return _authService.getUserRole(uid);
  }

  /// Returns the cached role lookup or starts a new one
  /// when the authenticated user's UID changes.
  Future<UserRole> _getOrFetchRole(String uid) {
    if (_cachedUid != uid || _roleFuture == null) {
      _cachedUid = uid;
      _roleFuture = _fetchRoleWithRetry(uid);
    }

    return _roleFuture!;
  }

  /// Clears the cached lookup and retries role retrieval.
  void _retryRoleFetch(String uid) {
    setState(() {
      _cachedUid = uid;
      _roleFuture = _fetchRoleWithRetry(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          _cachedUid = null;
          _roleFuture = null;

          return const LoginScreen();
        }

        return FutureBuilder<UserRole>(
          future: _getOrFetchRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (roleSnapshot.hasError || !roleSnapshot.hasData) {
              final message = roleSnapshot.error?.toString() ??
                  'Unable to verify your account role.';

              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ErrorState(
                          message: message,
                          onRetry: () => _retryRoleFetch(user.uid),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton.icon(
                          onPressed: () => _authService.signOut(),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign Out'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return roleSnapshot.data == UserRole.doctor
                ? const DoctorShell()
                : const PatientShell();
          },
        );
      },
    );
  }
}
