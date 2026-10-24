import 'package:flutter/material.dart';
import 'package:websupark/theme/app_colors.dart';

/// Temporary page shown where a real prototype screen has not been built yet.
/// Each screen owner replaces this with their real screen.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.screenCode,
    required this.owner,
  });

  final String title; // name of the prototype screen
  final String screenCode; // code from the prototype checklist, e.g. D1
  final String owner; // who builds this screen

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Prototype screen $screenCode',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            Text(
              'Owner: $owner',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}