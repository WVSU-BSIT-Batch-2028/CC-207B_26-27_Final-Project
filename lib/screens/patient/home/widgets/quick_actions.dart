import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Four shortcuts under the hero card.
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
    // The row is capped at 420 px and spreads the four buttons evenly inside it:
    // on a phone it fills the width, on a laptop it stays centered instead of
    // stretching edge to edge.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickAction(icon: Icons.add_circle_outline_rounded, label: 'Book', onTap: onBook),
            _QuickAction(icon: Icons.autorenew_rounded, label: 'Refill', onTap: onRefill),
            _QuickAction(icon: Icons.folder_shared_rounded, label: 'Records', onTap: onRecords),
            _QuickAction(icon: Icons.auto_awesome_rounded, label: 'Ask AI', onTap: onAskAi, highlight: true),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.highlight = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: highlight ? AppColors.heroGradient : null,
                  color: highlight ? null : AppColors.surface,
                  shape: BoxShape.circle,
                  border: highlight ? null : Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: highlight ? Colors.white : AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
