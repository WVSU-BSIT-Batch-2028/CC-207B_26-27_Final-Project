import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/user_role.dart';
import '../../widgets/coming_soon_sheet.dart';
import '../../widgets/menu_tile.dart';
import 'faq_screen.dart';

/// Help & Support: FAQs, Contact Us, Call Us, Live Chat.
/// For patients, Live Chat opens the AI assistant.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, required this.role});

  final UserRole role;

  static const String _email = 'support@health360.example';
  static const String _phone = '(033) 000-0000';

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
        children: [
          MenuTile(
            icon: Icons.quiz_rounded,
            title: 'FAQs',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FaqScreen())),
          ),
          MenuTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contact Us',
            subtitle: _email,
            onTap: () => _copy(context, 'Email address', _email),
          ),
          MenuTile(
            icon: Icons.call_outlined,
            title: 'Call Us',
            subtitle: _phone,
            onTap: () => _copy(context, 'Phone number', _phone),
          ),
          MenuTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Live Chat',
            subtitle: 'Chat with the Health360 Assistant',
            onTap: () {
              if (role == UserRole.patient) {
                Navigator.of(context).pushNamed(AppRoutes.assistant);
              } else {
                showComingSoonSheet(context, title: 'Live Chat',
                    message: 'Doctor support chat is planned for a future release.');
              }
            },
          ),
        ],
      ),
    );
  }
}
