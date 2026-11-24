import 'package:flutter/material.dart';

import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// The privacy notice a customer accepts at sign-up.
// Compliant with the Philippine Data Privacy Act of 2012 (RA 10173).
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const _AppBarTitle(
        icon: Icons.policy_outlined,
        title: 'Privacy Notice',
        subtitle: 'How MediTech handles your data',
      )),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          _NoticeTitle(),
          SizedBox(height: AppSpacing.sm),
          _EffectiveDate(),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '1. Who We Are',
            body:
                'MediTech is a medicine reservation platform that connects '
                'customers with licensed pharmacies in the Philippines. As the '
                'operator of this application, MediTech acts as the personal '
                'information controller under the Philippine Data Privacy Act of '
                '2012 (Republic Act No. 10173) and its Implementing Rules and '
                'Regulations.\n\n'
                'For any privacy-related concerns, you may contact our Data '
                'Protection Officer at:\n'
                'Email: privacy@meditech.ph\n'
                'Address: MediTech, Philippines',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '2. Personal Information We Collect',
            body:
                'We collect the following personal information when you create '
                'an account and use the app:\n\n'
                '• Full name\n'
                '• Mobile number\n'
                '• Email address\n'
                '• Date of birth\n'
                '• Delivery or pickup addresses you save\n'
                '• Profile photo (if you choose to upload one)\n\n'
                'When you search for medicines or make a reservation, we also '
                'collect:\n\n'
                '• Medicine names and categories you search for\n'
                '• Search filters you apply (dosage form, strength, location)\n'
                '• Approximate location when you allow location access, used '
                'only to show nearby pharmacies\n'
                '• Reservation details: medicines requested, quantities, chosen '
                'pharmacy, and reservation timestamps\n'
                '• Device information and app usage logs for performance and '
                'security monitoring\n\n'
                'We do not collect unnecessary sensitive personal information. '
                'If a medicine requires a prescription (Rx), we note this '
                'requirement for the pharmacy but do not store your prescription '
                'documents on our servers.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '3. How We Use Your Information',
            body:
                'We process your personal information for the following '
                'purposes, all of which are necessary to provide the MediTech '
                'service:\n\n'
                '• Account management — to create, authenticate, and maintain '
                'your account\n'
                '• Medicine search — to return relevant search results based on '
                'your query, filters, and location\n'
                '• Reservations — to send your reservation details to the '
                'pharmacy you selected and to allow you to track reservation '
                'status\n'
                '• Notifications — to send you reservation confirmations, '
                'status updates, and service-related alerts via push '
                'notification or SMS\n'
                '• Customer support — to respond to your inquiries and resolve '
                'issues with your account or reservations\n'
                '• Security and fraud prevention — to detect and prevent '
                'unauthorized access and misuse of the platform\n'
                '• Service improvement — to analyze aggregated, anonymized '
                'usage patterns and improve app features\n\n'
                'We will not use your personal information for any purpose '
                'beyond those listed above without obtaining your prior consent.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '4. Medicine Search and Reservation Data',
            body:
                'Your search history is stored locally on your device to '
                'display recent searches for your convenience. It is not '
                'uploaded to our servers and can be cleared at any time from '
                'the app.\n\n'
                'Reservation records — including which medicines you reserved, '
                'the pharmacy, quantities, and status — are stored on our '
                'servers so that both you and the pharmacy can track the '
                'reservation. These records are retained for a period of two '
                '(2) years from the date of the reservation, after which they '
                'are permanently deleted.\n\n'
                'Location data obtained from your device is used only in '
                'real-time to sort pharmacy results by proximity. It is not '
                'stored after the search response is returned.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '5. How We Store and Protect Your Data',
            body:
                'Your personal information is stored on secure cloud servers '
                'hosted by Supabase (located within or accessible under '
                'jurisdictions with adequate data protection standards). We '
                'implement the following safeguards:\n\n'
                '• Encryption in transit — all data exchanged between the app '
                'and our servers is encrypted using TLS (HTTPS)\n'
                '• Encryption at rest — your data is encrypted in the database '
                'at the storage level\n'
                '• Access controls — only authorized MediTech staff and systems '
                'can access the database, governed by the principle of least '
                'privilege\n'
                '• Row-level security — database policies ensure that users can '
                'only access their own records; pharmacy staff can only view '
                'reservations directed to their pharmacy\n'
                '• Audit logging — significant account and platform events are '
                'logged to support security investigations\n\n'
                'Despite these measures, no system is entirely risk-free. In '
                'the event of a personal data breach that is likely to cause '
                'harm to you, we will notify the National Privacy Commission '
                '(NPC) and affected users within 72 hours of discovery, as '
                'required by RA 10173.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '6. Sharing Information with Partner Pharmacies',
            body:
                'When you place a reservation, we share the following '
                'information with the pharmacy you selected:\n\n'
                '• Your full name\n'
                '• Your mobile number (so the pharmacy can contact you)\n'
                '• The medicines you reserved, quantities, and any notes you '
                'included\n\n'
                'Pharmacies receive only what is necessary to fulfill your '
                'reservation. They do not have access to your complete account '
                'profile, your search history, or reservations you placed at '
                'other pharmacies.\n\n'
                'Partner pharmacies are bound by their own obligations under '
                'RA 10173 and must handle your information in accordance with '
                'applicable law. MediTech is not responsible for how a pharmacy '
                'manages data it independently controls after receipt.\n\n'
                'We do not sell, rent, or otherwise share your personal '
                'information with any third party for marketing or commercial '
                'purposes.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '7. Your Rights Under RA 10173',
            body:
                'As a data subject under the Philippine Data Privacy Act of '
                '2012, you have the following rights:\n\n'
                '• Right to be informed — to know how your personal information '
                'is collected, stored, and used (this notice fulfills that '
                'obligation)\n'
                '• Right to access — to request a copy of the personal '
                'information we hold about you\n'
                '• Right to rectification — to request correction of inaccurate '
                'or outdated personal information\n'
                '• Right to erasure or blocking — to request deletion or '
                'blocking of your personal information when it is no longer '
                'necessary, or when you withdraw consent, subject to our legal '
                'retention obligations\n'
                '• Right to object — to object to the processing of your '
                'personal information for specific purposes, including direct '
                'marketing\n'
                '• Right to data portability — to receive your personal '
                'information in a structured, commonly used format\n'
                '• Right to lodge a complaint — to file a complaint with the '
                'National Privacy Commission (NPC) if you believe your rights '
                'have been violated\n\n'
                'To exercise any of these rights, send a written request to '
                'privacy@meditech.ph. We will respond within fifteen (15) '
                'working days. We may ask you to verify your identity before '
                'processing the request.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '8. Retention of Personal Information',
            body:
                'We retain your personal information for as long as your '
                'account is active, or as long as necessary to provide you '
                'with the service. Specifically:\n\n'
                '• Account data (name, email, mobile, birthdate) — retained '
                'while your account exists and for one (1) year after '
                'deletion, to allow account recovery and comply with legal '
                'obligations\n'
                '• Reservation records — retained for two (2) years from the '
                'reservation date\n'
                '• Device and usage logs — retained for ninety (90) days\n\n'
                'When the retention period expires, your data is permanently '
                'and securely deleted.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '9. Children\'s Privacy',
            body:
                'MediTech is not intended for use by individuals under 18 '
                'years of age. We do not knowingly collect personal information '
                'from minors. If we become aware that a minor has created an '
                'account without parental consent, we will delete the account '
                'and associated data promptly.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '10. Changes to This Notice',
            body:
                'We may update this Privacy Notice from time to time to reflect '
                'changes in the law or our practices. When we make material '
                'changes, we will notify you through the app and update the '
                'effective date below. Continued use of MediTech after the '
                'updated notice takes effect constitutes your acceptance of the '
                'changes.',
          ),
          SizedBox(height: AppSpacing.xl),
          _Section(
            heading: '11. Contact Us',
            body:
                'If you have questions about this Privacy Notice or wish to '
                'exercise your data subject rights, please contact our Data '
                'Protection Officer:\n\n'
                'Email: privacy@meditech.ph\n\n'
                'You may also file a complaint with the National Privacy '
                'Commission at:\n'
                'Website: www.privacy.gov.ph\n'
                'Email: complaints@privacy.gov.ph',
          ),
          SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _NoticeTitle extends StatelessWidget {
  const _NoticeTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'MediTech Privacy Notice',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }
}

class _EffectiveDate extends StatelessWidget {
  const _EffectiveDate();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Effective date: November 24, 2026\n'
      'In accordance with Republic Act No. 10173 (Data Privacy Act of 2012)',
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textMuted,
        height: 1.5,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
