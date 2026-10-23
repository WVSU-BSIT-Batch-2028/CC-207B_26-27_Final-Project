import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/h360_card.dart';
import '../../../../widgets/status_chip.dart';

/// Entry point to the AI assistant from the Home screen.
class AssistantPromoCard extends StatelessWidget {
  const AssistantPromoCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Health360 Assistant',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
                      ),
                    ),
                    SizedBox(width: 8),
                    StatusChip(label: 'AI', color: AppColors.primary),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Describe how you feel and get guidance on what to do next.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
