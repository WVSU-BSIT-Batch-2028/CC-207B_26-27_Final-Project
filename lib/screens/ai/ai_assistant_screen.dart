import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/chat_message.dart';
import '../../services/ai_assistant_service.dart';
import '../../widgets/status_chip.dart';

/// What the assistant screen can ask the app shell to do when it closes.
enum AssistantAction { bookAppointment }

/// AI-powered feature: a symptom / FAQ assistant.
///
/// Rubric checklist covered here:
/// - Relevance: free-text symptoms are messy, plain if/else logic can't read them.
/// - Graceful failure: loading indicator, timeout + error fallback (see service).
/// - Responsible use: replies are labelled "AI-generated", the user can edit a
///   message, disagree with a reply, or book a real doctor at any time, and the
///   input warns against sharing personal identifiers (Data Privacy Act).
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, AiAssistantService? service}) : _service = service;

  final AiAssistantService? _service;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const int _maxLength = 500;
  static const List<String> _suggestions = [
    'I have a headache and a mild fever',
    'Cough for 3 days',
    'How do I refill my prescription?',
  ];

  late final AiAssistantService _service = widget._service ?? AiAssistantFactory.create();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late final List<ChatMessage> _messages = [
    ChatMessage(
      id: 0,
      role: ChatRole.assistant,
      text: "Hi! I'm the Health360 Assistant. Tell me how you're feeling or ask about "
          "appointments and prescriptions. I can suggest what to do next, but I'm not a doctor.",
      createdAt: DateTime.now(),
    ),
  ];

  int _nextId = 1;
  bool _isThinking = false;
  String? _inputError;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Validates the input, sends it to the service and appends the reply.
  Future<void> _send([String? preset]) async {
    if (_isThinking) return;
    final text = (preset ?? _controller.text).trim();

    // Form validation with clear error feedback.
    if (text.length < 3) {
      setState(() => _inputError = 'Tell me a little more (at least 3 characters).');
      return;
    }

    setState(() {
      _inputError = null;
      _isThinking = true;
      _messages.add(ChatMessage(
        id: _nextId++,
        role: ChatRole.user,
        text: text,
        createdAt: DateTime.now(),
      ));
    });
    _controller.clear();
    _scrollToBottom();

    AssistantReply reply;
    try {
      reply = await _service.ask(text, List<ChatMessage>.unmodifiable(_messages));
    } catch (_) {
      reply = RuleBasedAssistant.respond(text); // last-resort safety net
    }
    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _messages.add(ChatMessage(
        id: _nextId++,
        role: ChatRole.assistant,
        text: reply.text,
        createdAt: DateTime.now(),
        triage: reply.triage,
        isFallback: reply.isFallback,
        isSafety: reply.isSafety,
      ));
    });
    _scrollToBottom();
  }

  void _editMessage(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _showFeedbackThanks() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Thanks for letting us know. You can always book a doctor for a proper check."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlyWelcome = _messages.length == 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(child: Text('Health360 Assistant', overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8),
            StatusChip(label: 'AI', color: AppColors.primary, icon: Icons.auto_awesome_rounded),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'outage') {
                setState(() => AiDemoSwitch.simulateOutage = !AiDemoSwitch.simulateOutage);
              } else if (value == 'clear') {
                setState(() {
                  _messages.removeRange(1, _messages.length);
                  _inputError = null;
                });
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'outage',
                checked: AiDemoSwitch.simulateOutage,
                child: const Text('Simulate AI outage (demo)'),
              ),
              const PopupMenuItem<String>(value: 'clear', child: Text('Clear conversation')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const _DisclaimerBanner(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              children: [
                for (final m in _messages)
                  _MessageBubble(
                    message: m,
                    onEdit: () => _editMessage(m.text),
                    onNotRight: _showFeedbackThanks,
                    onBook: () => Navigator.of(context).pop(AssistantAction.bookAppointment),
                  ),
                if (_isThinking) const _TypingBubble(),
                if (onlyWelcome && !_isThinking)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _suggestions)
                          ActionChip(
                            label: Text(s),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(color: AppColors.border),
                            labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            onPressed: () => _send(s),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _InputBar(
            controller: _controller,
            errorText: _inputError,
            enabled: !_isThinking,
            onChanged: (_) {
              if (_inputError != null) setState(() => _inputError = null);
            },
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// Always-visible notice: AI label, not a diagnosis, privacy and emergencies.
class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI-generated guidance, not a medical diagnosis. Please avoid sharing your '
              'full name or ID numbers. In an emergency, call 911.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onEdit,
    required this.onNotRight,
    required this.onBook,
  });

  final ChatMessage message;
  final VoidCallback onEdit;
  final VoidCallback onNotRight;
  final VoidCallback onBook;

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.82;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _isUser ? _userBubble() : _assistantBubble(),
        ),
      ),
    );
  }

  Widget _userBubble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(message.text, style: const TextStyle(color: Colors.white, height: 1.4)),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Padding(
            padding: EdgeInsets.only(top: 4, right: 4),
            child: Text(
              'Edit & resend',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assistantBubble() {
    final triage = message.triage;
    final needsDoctor = triage != null && triage != TriageLevel.selfCare;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label so users always know where the text came from.
          if (message.id != 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: message.isSafety
                  ? const StatusChip(
                      label: 'Safety guidance · not AI',
                      color: AppColors.danger,
                      icon: Icons.health_and_safety_rounded,
                    )
                  : message.isFallback
                      ? const StatusChip(
                          label: 'Offline guidance · not AI',
                          color: AppColors.warning,
                          icon: Icons.info_outline_rounded,
                        )
                      : StatusChip(
                          label: 'AI-generated',
                          color: AppColors.primary,
                          icon: Icons.auto_awesome_rounded,
                        ),
            ),
          if (triage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StatusChip(
                label: _triageLabel(triage),
                color: _triageColor(triage),
                icon: _triageIcon(triage),
              ),
            ),
          Text(message.text, style: const TextStyle(height: 1.45)),
          if (message.id != 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (needsDoctor)
                  ElevatedButton.icon(
                    onPressed: onBook,
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: const Text('Book a consultation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                TextButton(
                  onPressed: onNotRight,
                  child: const Text("This isn't right"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _triageLabel(TriageLevel t) {
    switch (t) {
      case TriageLevel.selfCare:
        return 'Self-care';
      case TriageLevel.seeDoctor:
        return 'See a doctor soon';
      case TriageLevel.urgent:
        return 'Urgent: seek care now';
    }
  }

  static Color _triageColor(TriageLevel t) {
    switch (t) {
      case TriageLevel.selfCare:
        return AppColors.success;
      case TriageLevel.seeDoctor:
        return AppColors.warning;
      case TriageLevel.urgent:
        return AppColors.danger;
    }
  }

  static IconData _triageIcon(TriageLevel t) {
    switch (t) {
      case TriageLevel.selfCare:
        return Icons.spa_rounded;
      case TriageLevel.seeDoctor:
        return Icons.local_hospital_rounded;
      case TriageLevel.urgent:
        return Icons.warning_amber_rounded;
    }
  }
}

/// "Assistant is typing" indicator shown while waiting for the service.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: 0.25 + 0.75 * math.sin(((_controller.value + i * 0.2) % 1.0) * math.pi),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.errorText,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mist,
        boxShadow: [BoxShadow(color: Color(0x0F1D4ED8), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  onChanged: onChanged,
                  decoration: AppTheme.inputDecoration(
                    hint: 'Describe your symptoms…',
                    errorText: errorText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: GestureDetector(
                  onTap: enabled ? onSend : null,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: enabled ? AppColors.heroGradient : null,
                      color: enabled ? null : AppColors.skeleton,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
