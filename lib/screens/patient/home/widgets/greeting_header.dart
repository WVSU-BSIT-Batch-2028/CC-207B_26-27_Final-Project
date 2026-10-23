import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';

/// "Good Morning, Jahna" + avatar. Long-press the avatar to open the
/// demo menu (switch between normal / empty / error states).
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    this.name,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
  });

  final String? name;
  final VoidCallback onAvatarTap;
  final VoidCallback onAvatarLongPress;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingFor(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? greeting : '$greeting, $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Take care of your health today.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Open profile',
          child: GestureDetector(
            onTap: onAvatarTap,
            onLongPress: onAvatarLongPress,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(Icons.person_outline_rounded, color: AppColors.navy),
            ),
          ),
        ),
      ],
    );
  }
}
