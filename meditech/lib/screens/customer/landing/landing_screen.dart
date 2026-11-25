import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// First customer page matched to the Main Flow landing frame
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Column(
                children: [
                  Image.asset(
                    'assets/images/Meditech Logo.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'MediTech',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                "Let's make finding medicine easier",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Search, compare, and manage your prescriptions with confidence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => context.push('/sign-up'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: pill,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Get started'),
                    SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: pill,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  foregroundColor: AppColors.primary,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue as guest'),
                    SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/sign-in'),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
