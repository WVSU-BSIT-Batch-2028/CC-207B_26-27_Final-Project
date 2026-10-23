import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';

/// "Confirming Log Out" step from the prototype. With no real session yet,
/// logging out simply returns to the role gate. The Auth owner should also
/// clear the signed-in user here.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Log out?', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
      content: const Text('You will return to the start screen.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Log Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.roleGate, (route) => false);
  }
}
