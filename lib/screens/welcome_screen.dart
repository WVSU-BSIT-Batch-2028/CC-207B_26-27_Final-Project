import 'package:flutter/material.dart';
import '../foodwise_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 24, 25, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: FoodWiseColors.deepOrange,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Text(
                        'FoodWise',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Container(
                    height: 210,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFA64D),
                          Color(0xFFE96B10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'YOUR FOOD DISCOVERY STARTS HERE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 17),
                              const Text(
                                'Eat well.\nSpend wisely.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Affordable meals are closer than you think.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 82,
                          width: 82,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.ramen_dining_rounded,
                            color: Colors.white,
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Good food, made easy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 39,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.6,
                      color: FoodWiseColors.charcoal,
                    ),
                  ),

                  const SizedBox(height: 13),
                  const Text(
                    'Discover affordable meals and make smarter food choices around your campus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: FoodWiseColors.muted,
                    ),
                  ),

                  const SizedBox(height: 30),
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Text('Sign In'), SizedBox(width: 9), Icon(Icons.arrow_forward_rounded, size: 19)],
                    ),
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FoodWiseColors.deepOrange,
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: FoodWiseColors.orange, width: 1.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),

                  const SizedBox(height: 23),
                  const Text(
                    'DISCOVER  \u2022  EAT  \u2022  ENJOY',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FoodWiseColors.muted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
