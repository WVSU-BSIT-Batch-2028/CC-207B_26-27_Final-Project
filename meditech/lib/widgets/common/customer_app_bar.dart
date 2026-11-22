import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'customer_location_title.dart';

// App bar title block: optional screen label plus customer area / location status.
class CustomerLocationAppBarTitle extends ConsumerWidget {
  const CustomerLocationAppBarTitle({
    super.key,
    this.heading,
    this.headingStyle,
  });

  final String? heading;
  final TextStyle? headingStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headingText = heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (headingText != null && headingText.isNotEmpty) ...[
          Text(
            headingText,
            style: headingStyle ??
                const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],
        const Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 4),
            Expanded(
              child: CustomerLocationTitle(
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}