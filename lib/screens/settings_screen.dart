import 'package:flutter/material.dart';

import 'dietary_settings_screen.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _background = Color(0xFFFFF8F1);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFFE96B10);
  static const _lightOrange = Color(0xFFFFE7D1);
  static const _charcoal = Color(0xFF30251F);
  static const _muted = Color(0xFF88786E);
  static const _border = Color(0xFFF0DFD2);

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String description,
    required String detail,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _lightOrange,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 25),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _charcoal,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                const Text(
                  'Make FoodWise yours.',
                  style: TextStyle(
                    color: _charcoal,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Manage your account separately from the food preferences used to personalize your meal recommendations.',
                  style: TextStyle(color: _muted, height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 25),
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                _settingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile Settings',
                  description: 'Update your personal information and protect your account.',
                  detail: 'Profile photo · Name · Email · Phone · Password',
                  onTap: () => _open(context, const ProfileSettingsScreen()),
                ),
                const SizedBox(height: 22),
                const Text(
                  'PERSONALIZATION',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                _settingsTile(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Dietary Settings',
                  description: 'Choose the foods you enjoy and tell FoodWise about allergies or restrictions.',
                  detail: 'Favorite foods · Eating pattern · Foods to avoid · Allergies',
                  onTap: () => _open(context, const DietarySettingsScreen()),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: _primary,
                        size: 21,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your dietary settings are shared with the AI Meal Assistant. Profile information is managed separately and does not determine which meals are recommended.',
                          style: TextStyle(
                            color: _charcoal,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'FoodWise · Good food. Smart choices. Better days.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
