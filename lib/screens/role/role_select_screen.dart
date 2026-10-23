import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/h360_card.dart';

/// TEMPORARY entry screen (no login yet): pick which side to explore.
/// The Auth owner replaces this with the real login / registration flow and
/// then routes to AppRoutes.patientShell or AppRoutes.doctorShell by role.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeSlideIn(
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(color: Color(0x551D4ED8), blurRadius: 28, offset: Offset(0, 12)),
                          ],
                        ),
                        child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Health360',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text('Healthcare for the Future', style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: _RoleCard(
                    icon: Icons.favorite_rounded,
                    title: 'Continue as Patient',
                    description: 'Dashboard, health summary, medications and the AI assistant.',
                    onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.patientShell),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: _RoleCard(
                    icon: Icons.medical_services_rounded,
                    title: 'Continue as Doctor',
                    description: "Today's schedule, quick overview, dashboard and profile.",
                    onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.doctorShell),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Demo access: login is not built yet. You can switch sides any time '
                            'from Profile > Switch view.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                          ),
                        ),
                      ],
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
