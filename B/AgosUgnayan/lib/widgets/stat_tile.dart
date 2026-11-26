// Small summary boxes for the home dashboards, e.g. "3 active crops" or
// "12 buyer requests". Tapping one opens the page with the details.

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// A white tile with an icon, a big number and a short label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    this.highlight = false,
  });

  final IconData icon;

  /// The number, already formatted, e.g. "12" or "₱38.81".
  final String value;
  final String label;

  /// Opens the related page. Null makes the tile not tappable.
  final VoidCallback? onTap;

  /// True paints the tile brand green, for the most important number.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? Colors.white : AppColors.text;
    return Card(
      color: highlight ? AppColors.primary : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: highlight
                          ? Colors.white.withValues(alpha: 0.18)
                          : AppColors.primaryLight,
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: highlight ? Colors.white : AppColors.link,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: highlight ? Colors.white70 : AppColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: AppTextStyles.statNumber.copyWith(color: foreground),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: highlight ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out stat tiles: 2 per row on a phone, up to 4 on a wide screen.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}
