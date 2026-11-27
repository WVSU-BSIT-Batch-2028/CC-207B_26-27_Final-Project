import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/h360_card.dart';

/// Frequently asked questions (expandable list).
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<(String, String)> _faqs = [
    (
      'How do I book an appointment?',
      'Open the Appointment tab, choose a doctor, pick a date and time, then confirm. '
          'Your booking appears on the Home screen.',
    ),
    (
      'How do video consultations work?',
      'Video consultations are held through Google Meet. The link is shown in your '
          'appointment details before the session.',
    ),
    (
      'How do I request a prescription refill?',
      'Go to the Prescription tab, open the medicine and choose refill. You can track the request there.',
    ),
    (
      'Is the AI assistant a doctor?',
      'No. It gives general guidance and always labels its replies as AI-generated. '
          'It cannot diagnose conditions. For anything worrying, book a consultation.',
    ),
    (
      'Is my personal data safe?',
      'Health360 only collects what each feature needs, in line with the Data Privacy Act '
          'of 2012 (RA 10173). Avoid sharing ID numbers in chat.',
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
        title: const Text('FAQs'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
        children: [
          for (final faq in _faqs)
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
                    title: Text(faq.$1, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    children: [Text(faq.$2, style: TextStyle(color: AppColors.textMuted, height: 1.5))],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
