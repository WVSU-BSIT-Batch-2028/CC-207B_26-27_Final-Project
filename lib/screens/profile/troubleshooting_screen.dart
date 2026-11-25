import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/contact_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/h360_button.dart';
import '../../widgets/h360_card.dart';

/// Common Problems: each opens short numbered steps (HCI feedback).
class TroubleshootingScreen extends StatelessWidget {
  const TroubleshootingScreen({super.key});

  static const List<(String, List<String>)> _problems = [
    (
      "I can't join my video consultation",
      [
        'Open your appointment and tap Join. The link opens in Google Meet.',
        'If asked, allow the camera and microphone.',
        'Open the link in your phone browser or install the Google Meet app if it does not open.',
        'Check your internet. Move closer to your router or switch between Wi-Fi and mobile data.',
        'Still stuck? Contact the clinic with the button below.',
      ],
    ),
    (
      "I didn't get a reminder",
      [
        'Open Profile > Notifications and make sure that type is switched on.',
        'Check that notifications are allowed for the app in your phone settings.',
        'Open the appointment or prescription and confirm the reminder time you set.',
      ],
    ),
    (
      'The app is slow or shows an error',
      [
        'Check your internet connection.',
        'Pull down on the screen to refresh, or tap Try again.',
        'Close the app completely and open it again.',
        'If it keeps happening, contact the clinic.',
      ],
    ),
    (
      'I forgot my password',
      [
        'On the login screen, tap Forgot password.',
        'Follow the steps sent to your email. Check the spam folder if nothing arrives.',
        'If it still does not work, contact the clinic.',
      ],
    ),
    (
      'My health numbers look wrong',
      [
        'Tap the card on Home to see where the number came from.',
        'Add the correct reading with Add a reading.',
        'Talk to your doctor about any numbers that worry you.',
      ],
    ),
    (
      'The text is too small',
      [
        'Open Profile > App Theme.',
        'Under Text size, choose Large or Extra large.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Common Problems'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Tap a problem to see the steps.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ),
          for (final problem in _problems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: H360Card(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: AppColors.primary,
                    title: Text(problem.$1, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    children: [
                      for (var i = 0; i < problem.$2.length; i++) _Step(number: i + 1, text: problem.$2[i]),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          H360Button(
            label: 'Contact the clinic',
            icon: Icons.call_outlined,
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: ContactInfo.supportPhone));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clinic phone number copied.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One numbered step.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.14), shape: BoxShape.circle),
            child: Text('$number', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
