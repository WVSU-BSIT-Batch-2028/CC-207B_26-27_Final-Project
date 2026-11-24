import 'package:flutter/material.dart';

import '../foodwise_theme.dart';

import 'dietary_settings_screen.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
      color: FoodWiseColors.surface,
      borderRadius: BorderRadius.circular(FoodWiseRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FoodWiseRadius.large),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FoodWiseRadius.large),
            border: Border.all(color: FoodWiseColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: FoodWiseColors.lightOrange,
                  borderRadius: BorderRadius.circular(FoodWiseRadius.brand),
                ),
                child: Icon(icon, color: FoodWiseColors.deepOrange, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FoodWiseColors.charcoal,
                        fontSize: FoodWiseTypeSize.bodyLarge,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: FoodWiseSpacing.xs),
                    Text(
                      description,
                      style: const TextStyle(
                        color: FoodWiseColors.muted,
                        fontSize: FoodWiseTypeSize.caption,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: FoodWiseColors.deepOrange,
                        fontSize: FoodWiseTypeSize.overline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FoodWiseSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: FoodWiseColors.muted,
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodWiseColors.background,
      appBar: AppBar(
        backgroundColor: FoodWiseColors.background,
        foregroundColor: FoodWiseColors.charcoal,
        surfaceTintColor: FoodWiseColors.transparent,
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
                    color: FoodWiseColors.charcoal,
                    fontSize: FoodWiseTypeSize.pageLarge,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Manage your account separately from the food preferences used to personalize your meal recommendations.',
                  style: TextStyle(
                    color: FoodWiseColors.muted,
                    height: 1.5,
                    fontSize: FoodWiseTypeSize.supporting,
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: FoodWiseColors.muted,
                    fontSize: FoodWiseTypeSize.overline,
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
                    color: FoodWiseColors.muted,
                    fontSize: FoodWiseTypeSize.overline,
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
                const SizedBox(height: FoodWiseSpacing.xxl),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: FoodWiseColors.paleOrange,
                    borderRadius: BorderRadius.circular(FoodWiseRadius.control),
                    border: Border.all(color: FoodWiseColors.border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: FoodWiseColors.deepOrange,
                        size: 21,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your dietary settings are shared with the AI Meal Assistant. Profile information is managed separately and does not determine which meals are recommended.',
                          style: TextStyle(
                            color: FoodWiseColors.charcoal,
                            fontSize: FoodWiseTypeSize.caption,
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
                    style: TextStyle(
                      color: FoodWiseColors.muted,
                      fontSize: FoodWiseTypeSize.overline,
                    ),
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
