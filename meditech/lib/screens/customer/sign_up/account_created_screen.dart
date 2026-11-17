import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Shown after a customer finishes creating an account
class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.check_circle, size: 64, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Account created!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Welcome to MediTech. You can now search medicines across nearby pharmacies and send reservation requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
