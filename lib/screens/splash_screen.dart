import 'package:flutter/material.dart';
import '../foodwise_theme.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openNextScreen();
  }

  Future<void> _openNextScreen() async {
    // Briefly show the brand while Supabase restores the saved auth session.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final destination = AuthService.isLoggedIn()
        ? const StudentHomeScreen()
        : const WelcomeScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodWiseColors.deepOrange,
      body: Stack(
        children: [
          Positioned(
            top: -75,
            right: -55,
            child: _circle(220, Colors.white.withValues(alpha: .08)),
          ),
          Positioned(
            bottom: -95,
            left: -65,
            child: _circle(260, Colors.white.withValues(alpha: .08)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 104,
                  width: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: FoodWiseColors.deepOrange,
                    size: 57,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'FoodWise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'GOOD FOOD. SMART CHOICES.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 10,
                    letterSpacing: 2.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 42),
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
