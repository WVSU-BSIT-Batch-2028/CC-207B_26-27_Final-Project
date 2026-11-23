import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/theme/app_colors.dart';

// Modal after sign-up; only action is to open sign-in
Future<void> showAccountCreatedModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
      title: const Text('Account created'),
      content: const Text(
        'Your account is ready. Sign in with your email and password to start browsing pharmacies and placing reservations.',
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (context.mounted) {
              context.go('/sign-in');
            }
          },
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
}

// Deep-link target: shows the modal, then lands on sign-in
class AccountCreatedScreen extends StatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showAccountCreatedModal(context);
      if (mounted && context.mounted) {
        context.go('/sign-in');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}