// The first screen. It decides where to go: the setup message (no Firebase
// yet), the home screen (still logged in from last time) or the login screen.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Shows a spinner while checking for a saved login, then moves on.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.firebaseReady});

  /// True when main.dart connected to Firebase.
  final bool firebaseReady;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    // Wait until this screen has finished drawing once. Navigating while
    // Flutter is still building (e.g. no saved login, so no await happens
    // first) throws "cannot be marked as needing to build".
    if (widget.firebaseReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToFirstScreen());
    }
  }

  Future<void> _goToFirstScreen() async {
    final authService = AuthService();
    Widget next = const LoginScreen();
    final savedId = authService.savedLoginId;
    if (savedId != null) {
      try {
        await authService.loadProfile(savedId);
        next = const HomeScreen();
      } catch (_) {
        next = const LoginScreen(); // profile failed to load: log in again
      }
    }
    if (!mounted) return; // the screen was closed while we waited
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firebaseReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // No Firebase settings yet: explain what to do instead of crashing.
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.appName.toUpperCase())),
      body: const Padding(
        padding: EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
            SizedBox(height: AppSizes.fieldGap),
            Text(
              AppStrings.firebaseNotSetUpTitle,
              style: AppTextStyles.pageTitle,
            ),
            SizedBox(height: AppSizes.small),
            Text(AppStrings.firebaseNotSetUp),
          ],
        ),
      ),
    );
  }
}
