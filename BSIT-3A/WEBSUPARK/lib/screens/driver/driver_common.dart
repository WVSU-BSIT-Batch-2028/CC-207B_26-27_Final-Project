import 'package:flutter/material.dart';
import 'package:websupark/theme/app_colors.dart';

// Small building blocks shared by the driver screens (D2 to D5).
// They live inside the driver folder because only the driver interface uses them.

/// Small gray caps label used above some values, e.g. "YOUR VEHICLE".
const TextStyle driverLabelStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
  color: AppColors.textMuted,
);

/// Standard page body: scrollable, with the same padding on every screen.
class DriverPage extends StatelessWidget {
  const DriverPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Screen title and subtitle on the left, one icon button on the right.
class DriverHeader extends StatelessWidget {
  const DriverHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onIconTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onIconTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        DriverIconBox(icon: icon, onTap: onIconTap),
      ],
    );
  }
}

/// Rounded square holding an icon. Pale blue by default.
class DriverIconBox extends StatelessWidget {
  const DriverIconBox({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onTap; // null = not tappable
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: iconColor ?? AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Section title on the left, optional small blue text on the right.
class DriverSectionHeader extends StatelessWidget {
  const DriverSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onActionTap,
  });

  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
