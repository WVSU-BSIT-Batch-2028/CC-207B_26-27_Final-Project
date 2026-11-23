
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'welcome_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  // Sign out and return to Welcome Screen
  Future<void> logout(BuildContext context) async {
    try {
      await AuthService.logout();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to sign out: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Confirmation popup before signing out
  Future<void> confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          title: const Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFFFE7D1),
                child: Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFE96B10),
                  size: 30,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Sign Out?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Color(0xFF30251F),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out of your FoodWise account?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF88786E),
              height: 1.5,
              fontSize: 14,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE96B10),
                      side: const BorderSide(
                        color: Color(0xFFE96B10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE96B10),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      await logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodWise'),
        actions: [
          IconButton(
            onPressed: () => confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
          ),
        ],
      ),

      body: FutureBuilder<Map<String, dynamic>?>(
        future: AuthService.getProfile(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE96B10),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load student profile.'),
            );
          }

          final profile = snapshot.data;

          if (profile == null) {
            return const Center(
              child: Text('Student profile not found.'),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 90,
                  color: Color(0xFFE96B10),
                ),

                const SizedBox(height: 16),

                Text(
                  'Welcome, ${profile['full_name']}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text('Account Role: ${profile['role']}'),

                const SizedBox(height: 20),

                const Text(
                  'Your FoodWise student account is working!',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
