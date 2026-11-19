import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_providers.dart';
import '../../widgets/theme/app_colors.dart';
import '../../widgets/theme/app_spacing.dart';

// Suspended owners only see this page until their LTO is renewed
class SuspendedOwnerScreen extends ConsumerWidget {
  const SuspendedOwnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  'Pharmacy suspended',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Your pharmacy is hidden from customers. Upload a renewed FDA License to Operate so MediTech can review it. Full LTO renewal upload lands with the pharmacy verification screens.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Until your LTO is renewed and approved, staff cannot sign in and customers cannot see your branch.',
                    style: TextStyle(color: AppColors.text, height: 1.4),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).signOut();
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Switch user'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
