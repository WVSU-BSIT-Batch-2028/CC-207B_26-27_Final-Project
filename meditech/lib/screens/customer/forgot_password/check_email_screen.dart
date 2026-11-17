import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Shown after reset instructions are sent
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, this.identifier});

  final String? identifier;

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
                'Check your email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "We've sent reset instructions to your email. The link expires in 30 minutes.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Back to login'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.push(
                  '/forgot-password/reset',
                  extra: identifier,
                ),
                child: const Text('Enter the code from your email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
