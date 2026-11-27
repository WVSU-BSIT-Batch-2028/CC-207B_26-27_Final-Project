import 'package:final_project_look_out/app/themes/app_colors.dart';
import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;


  const ConfirmationDialog({
    super.key,
    this.title = 'Confirm Action',
    this.content = 'Are you sure?',
    this.confirmText = 'Confirm',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Text(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ['delete', 'remove'].contains(confirmText.toLowerCase())
            ? AppColor.errorRed
            : theme.colorScheme.primary,
          ),
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}