// The menu on the left of the screen on tablets and laptops: the logo on
// top, one button per tab (with a count when there is something new), and
// a card at the bottom with the logged-in user, Profile and Log out.
// On phones the same tabs are a bottom bar instead (see HomeScreen).

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import 'brand_app_bar.dart';

/// One menu button.
class SidebarItem {
  const SidebarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.count,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Shown as a small orange number, e.g. open buyer requests. Null hides it.
  final int? count;
}

/// The full sidebar with labels (about 248 px wide).
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.user,
    required this.onProfile,
    required this.onLogOut,
  });

  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AppUser user;
  final VoidCallback onProfile;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo on a green band, like the website's top bar.
            Container(
              height: 64,
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  AppLogo(size: 34),
                  SizedBox(width: 10),
                  Text(AppStrings.appName, style: AppTextStyles.logo),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SidebarButton(
                      item: items[i],
                      isSelected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            const Divider(),
            _UserCard(user: user, onProfile: onProfile, onLogOut: onLogOut),
          ],
        ),
      ),
    );
  }
}

/// One row in the sidebar; the selected one has a light green background.
class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryDark : AppColors.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusButton),
          onTap: onTap,
          child: Semantics(
            selected: isSelected,
            button: true,
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                    if (item.count != null && item.count! > 0)
                      CountBadge(count: item.count!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small orange pill with a number, e.g. "12" new buyer requests.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.accentInk,
        ),
      ),
    );
  }
}

/// Who is logged in, with Profile and Log out buttons.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onProfile,
    required this.onLogOut,
  });

  final AppUser user;
  final VoidCallback onProfile;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final role = user.role[0].toUpperCase() + user.role.substring(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user.town.isEmpty ? role : '$role · ${user.town}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: onProfile,
            icon: const Icon(Icons.person_outline, color: AppColors.textMuted),
          ),
          IconButton(
            tooltip: AppStrings.logOut,
            onPressed: onLogOut,
            icon: const Icon(Icons.logout, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
