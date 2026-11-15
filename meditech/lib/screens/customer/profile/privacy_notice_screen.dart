import 'package:flutter/material.dart';

import '../../../widgets/theme/app_spacing.dart';

// The privacy notice a customer accepts at sign-up
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy notice')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Text(
            'MediTech privacy notice v1',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'MediTech stores your name, mobile number, email, and birthdate so you can sign in and reserve medicine from a pharmacy. Pharmacy staff see only what they need for your reservation. You accepted this notice when you created your account.',
          ),
        ],
      ),
    );
  }
}