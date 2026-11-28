import 'package:flutter/material.dart';

import '../models/child.dart';
import '../theme/app_tokens.dart';
import 'brand_logo.dart';
import 'child_chip.dart';

/// Descriptor for a top-level destination in [ShellNavigationSidebar] and the
/// mobile bottom [NavigationBar].
@immutable
class ShellDestination {
  /// Creates a [ShellDestination].
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Icon displayed when this destination is inactive.
  final IconData icon;

  /// Icon displayed when this destination is selected.
  final IconData selectedIcon;

  /// Short tab label displayed beneath or beside the icon.
  final String label;
}

/// Adaptive side navigation rail displayed on wide desktop and tablet layouts.
class ShellNavigationSidebar extends StatelessWidget {
  /// Creates a [ShellNavigationSidebar].
  const ShellNavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.isExtended,
    required this.onDestinationSelected,
    required this.onHomeTap,
    required this.onAccountTap,
    this.activeChild,
    this.onChildTap,
    this.accountLabel,
  });

  /// Ordered list of top-level app navigation destinations.
  final List<ShellDestination> destinations;

  /// Index of the active destination.
  final int selectedIndex;

  /// Whether the sidebar renders in extended width with inline labels.
  final bool isExtended;

  /// Callback invoked when the caregiver selects a destination.
  final ValueChanged<int> onDestinationSelected;

  /// Callback invoked when the brand logo or home icon is tapped.
  final VoidCallback onHomeTap;

  /// Callback invoked when the caregiver taps the account footer button.
  final VoidCallback onAccountTap;

  /// Active child profile displayed in extended mode, if available.
  final Child? activeChild;

  /// Callback invoked when the caregiver taps the active child chip.
  final VoidCallback? onChildTap;

  /// Caregiver display name shown in the extended account footer.
  final String? accountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabelStyle = theme.textTheme.labelLarge?.copyWith(
      color: AppColors.forest,
      fontWeight: FontWeight.w600,
    );
    final unselectedLabelStyle = theme.textTheme.labelLarge?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: AppColors.surfaceCard,
      child: SizedBox(
        width: isExtended ? AppSizes.sidebarWidth : 80,
        child: Column(
          crossAxisAlignment: isExtended
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isExtended ? AppSpacing.space16 : AppSpacing.space8,
                AppSpacing.space20,
                isExtended ? AppSpacing.space16 : AppSpacing.space8,
                AppSpacing.space12,
              ),
              child: Column(
                crossAxisAlignment: isExtended
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (isExtended)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrandLogo(onTap: onHomeTap),
                    )
                  else
                    IconButton(
                      tooltip: 'LittleSteps home',
                      onPressed: onHomeTap,
                      icon: const GrowthSymbol(size: 28),
                    ),
                  if (activeChild != null && isExtended) ...[
                    const SizedBox(height: AppSpacing.space16),
                    ChildChip(activeChild: activeChild!, onTap: onChildTap),
                  ],
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, railConstraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: railConstraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: selectedIndex,
                          extended: isExtended,
                          minExtendedWidth: AppSizes.sidebarWidth,
                          labelType: isExtended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          backgroundColor: AppColors.surfaceCard,
                          useIndicator: true,
                          indicatorColor: AppColors.softGreen,
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                          selectedIconTheme: const IconThemeData(
                            color: AppColors.forest,
                            size: 22,
                          ),
                          unselectedIconTheme: const IconThemeData(
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                          selectedLabelTextStyle: selectedLabelStyle,
                          unselectedLabelTextStyle: unselectedLabelStyle,
                          onDestinationSelected: onDestinationSelected,
                          destinations: destinations
                              .map(
                                (d) => NavigationRailDestination(
                                  icon: Icon(d.icon),
                                  selectedIcon: Icon(d.selectedIcon),
                                  label: Text(d.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isExtended ? AppSpacing.space12 : AppSpacing.space8,
                vertical: AppSpacing.space12,
              ),
              child: isExtended
                  ? TextButton.icon(
                      onPressed: onAccountTap,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(AppSpacing.space8),
                      ),
                      icon: const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppColors.forest,
                      ),
                      label: Text(
                        accountLabel ?? 'Account',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppColors.forest,
                      ),
                      tooltip: 'Account',
                      onPressed: onAccountTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
