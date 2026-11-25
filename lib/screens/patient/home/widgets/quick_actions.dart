import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Four shortcuts under the hero card. Book is the main action, so it is
/// larger and brighter (HCI feedback).
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onBook,
    required this.onRefill,
    required this.onRecords,
    required this.onAskAi,
  });

  final VoidCallback onBook;
  final VoidCallback onRefill;
  final VoidCallback onRecords;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    // Capped at 420 px: full width on a phone, centred on a laptop.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // Bottoms line up, so the taller Book button stands out.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _QuickAction(icon: Icons.add_rounded, label: 'Book', onTap: onBook, style: _QuickStyle.featured),
            _QuickAction(icon: Icons.autorenew_rounded, label: 'Refill', onTap: onRefill),
            _QuickAction(icon: Icons.folder_shared_rounded, label: 'Records', onTap: onRecords),
            _QuickAction(icon: Icons.auto_awesome_rounded, label: 'Ask AI', onTap: onAskAi, style: _QuickStyle.ai),
          ],
        ),
      ),
    );
  }
}

/// Look of a shortcut: normal, the larger Book button, or AI gradient.
enum _QuickStyle { normal, featured, ai }

/// One round shortcut with its label.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.style = _QuickStyle.normal,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _QuickStyle style;

  @override
  Widget build(BuildContext context) {
    final featured = style == _QuickStyle.featured;
    final ai = style == _QuickStyle.ai;
    final size = featured ? 72.0 : 58.0;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: ai ? AppColors.heroGradient : null,
                  color: ai ? null : (featured ? AppColors.primary : AppColors.surface),
                  shape: BoxShape.circle,
                  border: (featured || ai) ? null : Border.all(color: AppColors.border),
                  boxShadow: featured
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: featured ? 38 : 26,
                  color: (featured || ai) ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: featured ? 15 : 14,
                  fontWeight: featured ? FontWeight.w900 : FontWeight.w700,
                  color: featured ? AppColors.primary : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
