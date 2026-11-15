import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/assistant_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_spacing.dart';

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

  // Send the question, then show the reply or the function's safe message
  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.isEmpty || _busy) return;
    if (ref.read(sessionProvider) == null) {
      setState(() {
        _lines.add(const _ChatLine(
          fromCustomer: false,
          text: 'Sign in before using the assistant.',
        ));
      });
      return;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.fromCustomer ? 'You' : 'Assistant',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(line.text),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Question',
                    controller: _question,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _busy ? null : _ask,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}