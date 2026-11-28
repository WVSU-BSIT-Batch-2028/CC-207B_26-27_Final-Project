import 'package:flutter/material.dart';

import '../routing/app_router.dart';
import '../theme/app_tokens.dart';
import 'brand_logo.dart';
import 'responsive_layout.dart';

/// Empty state view presented when no child profiles have been registered.
///
/// Welcomes the caregiver, displays the brand illustration, and provides
/// a primary call to action to configure their first child profile.
class NoChildrenView extends StatelessWidget {
  /// Creates a [NoChildrenView].
  const NoChildrenView({
    super.key,
    this.caregiverName,
    this.title = 'No children added yet',
    this.subtitle = 'Add your child to get ideas for their age.',
    this.actionLabel = 'Add a child',
    this.onAddChild,
  });

  /// Name or email prefix of the caregiver to personalize the greeting.
  final String? caregiverName;

  /// Primary card headline.
  final String title;

  /// Explanatory guidance beneath the card headline.
  final String subtitle;

  /// Label for the primary action button.
  final String actionLabel;

  /// Optional callback invoked when tapping the add button.
  final VoidCallback? onAddChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = caregiverName?.trim();
    final greeting = name != null && name.isNotEmpty
        ? 'Welcome, $name'
        : 'Welcome';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space24,
          vertical: AppSpacing.space24,
        ),
        child: ResponsiveContentBox(
          maxWidth: AppSizes.emptyStateMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                "Let's set up your first child profile.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space20),

              const ParentChildIllustration(height: 140),
              const SizedBox(height: AppSpacing.space20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.softGreen,
                      child: Icon(Icons.add, color: AppColors.forest, size: 28),
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.space20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            onAddChild ??
                            () => Navigator.pushNamed(
                              context,
                              AppRoutes.childrenAdd,
                            ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppSizes.touchTarget,
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),

              Text(
                'We only keep a nickname and age range. '
                'No birthdays, surnames or photos are required.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
