// "Message farmer" / "Message buyer" button. It opens (or creates) the chat
// with the other person and goes to the chat screen.

import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../utils/app_exception.dart';
import '../utils/snackbars.dart';
import 'loading_button.dart';

/// Opens the chat with [otherId], with [firstMessage] typed in for them.
class MessageButton extends StatefulWidget {
  const MessageButton({
    super.key,
    required this.otherId,
    required this.otherName,
    required this.label,
    this.firstMessage = '',
  });

  final String otherId;
  final String otherName;
  final String label;
  final String firstMessage; // ready to send, the user can change it

  @override
  State<MessageButton> createState() => _MessageButtonState();
}

class _MessageButtonState extends State<MessageButton> {
  bool _isLoading = false;

  Future<void> _openChat() async {
    final me = AuthService.currentUser!;
    setState(() => _isLoading = true);
    try {
      final chatId = await MessageService().openChat(
        myId: me.id,
        myName: me.name,
        otherId: widget.otherId,
        otherName: widget.otherName,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherName: widget.otherName,
            draft: widget.firstMessage,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingButton(
      label: widget.label,
      isLoading: _isLoading,
      onPressed: _openChat,
    );
  }
}
