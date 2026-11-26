// The buyer AI assistant on screen: a round button in the bottom-right
// corner and the chat panel it opens. It is placed once above every page
// (MaterialApp.builder), so it shows on pushed pages too. On phones the
// button sits above the bottom tab bar and the panel takes half the
// screen; on tablets and laptops the panel is 380 × 560 in the corner.

import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../services/assistant_controller.dart';
import '../utils/theme.dart';
import 'assistant_messages.dart';

/// Puts the assistant above [child] (the app's pages).
class AssistantLayer extends StatelessWidget {
  const AssistantLayer({super.key, required this.child, this.controller});

  final Widget child;

  /// The shared controller; tests pass their own.
  final AssistantController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? AssistantController.instance;
    return Stack(
      children: [
        child,
        // An Overlay gives the panel's text field and tooltips the support
        // they need. Where it draws nothing, taps go through to the app.
        Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ListenableBuilder(
                listenable: controller,
                builder: (context, _) => _AssistantUi(controller: controller),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssistantUi extends StatelessWidget {
  const _AssistantUi({required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.enabled) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final isPhone = size.width < AppSizes.wideBreakpoint;
    final page = controller.page;

    // Keep the button clear of the phone's tab bar and the chat's message
    // box, which both sit at the bottom.
    double bottom = 16 + padding.bottom;
    if (isPhone && controller.onTab) bottom += 80;
    if (page.screen == AssistantScreen.chat) bottom += 76;

    return Stack(
      children: [
        if (controller.showButton)
          Positioned(
            right: 16,
            bottom: bottom,
            child: _AssistantButton(onTap: controller.open),
          ),
        if (controller.isOpen && isPhone)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.6,
            child: AssistantPanel(controller: controller, isPhone: true),
          ),
        if (controller.isOpen && !isPhone)
          Positioned(
            right: 24,
            bottom: 24,
            width: 380,
            height: (size.height - 48).clamp(320, 560),
            child: AssistantPanel(controller: controller, isPhone: false),
          ),
      ],
    );
  }
}

/// The 52 px round button with a sparkle icon.
class _AssistantButton extends StatelessWidget {
  const _AssistantButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ask AgosUgnayan assistant',
      child: Semantics(
        button: true,
        label: 'Ask AgosUgnayan assistant',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chat panel: header, warning line, messages, question chips and the
/// text box.
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    super.key,
    required this.controller,
    required this.isPhone,
  });

  final AssistantController controller;
  final bool isPhone;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  AssistantController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    _c.removeListener(_scrollToEnd);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Shows the newest message after each change.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send([String? text, AssistantIntent? intent]) {
    final question = text ?? _input.text;
    if (question.trim().isEmpty || _c.isThinking) return;
    if (text == null) _input.clear();
    _c.ask(question, intent: intent);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.isPhone
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.circular(16);
    return Material(
      color: AppColors.surface,
      elevation: 8,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            const _AiNote(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  if (_c.messages.isEmpty)
                    const Text(
                      'Hi! Ask me about AgosUgnayan, prices and listings, or '
                      'just chat. I can only read: I never buy or send '
                      'messages for you.',
                      style: AppTextStyles.meta,
                    ),
                  for (final message in _c.messages)
                    AssistantMessageView(message: message, controller: _c),
                  if (_c.isThinking) const _Thinking(),
                ],
              ),
            ),
            if (_c.notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_c.notice!, style: AppTextStyles.meta),
              ),
            _chips(),
            _inputRow(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'AgosUgnayan assistant',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: _c.messages.isEmpty ? null : _c.newChat,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white60,
            ),
            child: const Text('New chat'),
          ),
          IconButton(
            tooltip: 'Close assistant',
            onPressed: _c.close,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// The suggested questions for this page, scrolling sideways.
  Widget _chips() {
    final chips = _c.suggestions;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return ActionChip(
            label: Text(chip.text, style: const TextStyle(fontSize: 13)),
            onPressed: _c.isThinking
                ? null
                : () => _send(chip.text, chip.intent),
          );
        },
      ),
    );
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Ask a question',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send question',
            onPressed: _c.isThinking ? null : _send,
            icon: const Icon(Icons.send, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// The one-line warning at the top of the panel.
class _AiNote extends StatelessWidget {
  const _AiNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: const Text(
        'AI can make mistakes. Check the listing details.',
        style: TextStyle(fontSize: 12, color: AppColors.warningInk),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Looking it up…', style: AppTextStyles.meta),
        ],
      ),
    );
  }
}
