import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/assistant_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../screens/shared/sign_in_sheet.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Suggested questions shown before the first reply
const _suggestions = [
  'Where can I find paracetamol 500mg?',
  'How do I place a reservation?',
  'Recommend a pharmacy for Biogesic',
];

// A customer asks a question and sees the assistant's reply
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _ChatLine {
  const _ChatLine({required this.fromCustomer, required this.text});

  final bool fromCustomer;
  final String text;
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _question = TextEditingController();
  final _lines = <_ChatLine>[];
  var _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  // Put a suggestion into the field and send it
  void _useSuggestion(String text) {
    _question.text = text;
    _ask();
  }

  // Send the question, then show the reply or the function's safe message
  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.isEmpty || _busy) return;

    // Guests must sign in first; keep them on this page afterward
    if (ref.read(sessionProvider) == null) {
      await showCustomerSignInSheet(context);
      if (!mounted || ref.read(sessionProvider) == null) return;
    }

    setState(() {
      _busy = true;
      _lines.add(_ChatLine(fromCustomer: true, text: question));
      _question.clear();
    });

    try {
      final answer = await ref.read(assistantServiceProvider).ask(question);
      setState(() => _lines.add(_ChatLine(fromCustomer: false, text: answer)));
    } on AppFailure catch (error) {
      setState(() => _lines.add(_ChatLine(fromCustomer: false, text: error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = _lines.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MediTech Assistant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'Here to help you find medicine.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: empty ? _EmptyState(onSuggestion: _useSuggestion) : _ChatList(lines: _lines),
          ),
          const Divider(height: 1, color: AppColors.border),
          _Composer(
            controller: _question,
            busy: _busy,
            onSend: _ask,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

// First view: disclaimer, greeting, and suggested questions
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Text(
            'MediTech AI helps you find medicines and track reservations. It does not give medical advice.',
            style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.text),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Text(
          'What can I help you today?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Not sure what to ask? Choose something:',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final suggestion in _suggestions) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OutlinedButton(
                onPressed: () => onSuggestion(suggestion),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                child: Text(suggestion),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        const Text(
          'Ask about listings, reservations, or how to use MediTech.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// Bubbles for questions the customer already asked
class _ChatList extends StatelessWidget {
  const _ChatList({required this.lines});

  final List<_ChatLine> lines;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final fromCustomer = line.fromCustomer;
        return Align(
          alignment: fromCustomer ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            decoration: BoxDecoration(
              color: fromCustomer ? AppColors.primaryLight : AppColors.neutralLight,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text(
              line.text,
              style: const TextStyle(fontSize: 15, height: 1.35, color: AppColors.text),
            ),
          ),
        );
      },
    );
  }
}

// Bottom field and round send button
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final canSend = !busy && controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask something...',
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: canSend ? AppColors.primary : AppColors.neutralLight,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? onSend : null,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward,
                          color: canSend ? Colors.white : AppColors.textMuted,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
