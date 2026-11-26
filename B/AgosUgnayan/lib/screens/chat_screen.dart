// F4 Messages: one conversation. Messages arrive live through a Firestore
// stream; the newest is at the bottom, like any chat app. Order messages
// show as live order cards (see OrderCard) with their buttons.

import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../services/assistant_controller.dart';

import '../models/chat.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/order_service.dart';
import '../utils/app_exception.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../widgets/offer_sheet.dart';
import '../widgets/order_card.dart';
import '../widgets/responsive_body.dart';
import '../widgets/async_state_view.dart';

/// The chat with [otherName]. [draft] is pre-typed text the user can send.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherName,
    this.draft = '',
  });

  final String chatId;
  final String otherName;
  final String draft;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = MessageService();
  final _myId = AuthService.currentUser!.id;
  late final _textController = TextEditingController(text: widget.draft);
  late Stream<List<ChatMessage>> _messages;
  // One live query for all order cards in this chat (not one per card).
  late final Stream<List<CropOrder>> _orders = OrderService().watchChat(
    widget.chatId,
    _myId,
  );
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = _service.watchMessages(widget.chatId);
    // Opening the chat means I've read it (removes the unread dot).
    _service.markRead(widget.chatId, _myId);
  }

  @override
  void dispose() {
    // Messages that came in while the chat was open count as read too.
    _service.markRead(widget.chatId, _myId);
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (text.length > 1000) {
      showError(context, AppStrings.tooLong(1000));
      return;
    }
    setState(() => _isSending = true);
    try {
      await _service.send(chatId: widget.chatId, senderId: _myId, text: text);
      _textController.clear();
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      // On a wide screen the chat stays a readable width in the middle.
      body: ResponsiveBody(
        maxWidth: 760,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<CropOrder>>(
                stream: _orders,
                builder: (context, orderSnapshot) {
                  final orders = {
                    for (final o in orderSnapshot.data ?? <CropOrder>[])
                      o.id: o,
                  };
                  // The AI assistant knows the newest order in this chat.
                  final newest = orderSnapshot.data?.firstOrNull;
                  return AssistantScope(
                    page: AssistantPage(AssistantScreen.chat, order: newest),
                    child: _buildMessages(orders),
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  /// The live list of messages; order messages become order cards.
  Widget _buildMessages(Map<String, CropOrder> orders) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messages,
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        return AsyncStateView(
          isLoading: snapshot.connectionState == ConnectionState.waiting,
          errorMessage: snapshot.hasError ? AppStrings.networkError : null,
          onRetry: () =>
              setState(() => _messages = _service.watchMessages(widget.chatId)),
          isEmpty: messages.isEmpty,
          emptyMessage: 'Say hello to ${widget.otherName}!',
          // reverse: true puts item 0 (the newest) at the bottom.
          builder: (context) => ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.pagePadding,
              vertical: 12,
            ),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final order = orders[message.orderId];
              // Until its order loads, it shows as normal text.
              if (message.isOrderCard && order != null) {
                return _buildOrderCard(message, order);
              }
              return _buildBubble(message);
            },
          ),
        );
      },
    );
  }

  /// An order card on the sender's side, with the live status and buttons.
  Widget _buildOrderCard(ChatMessage message, CropOrder order) {
    final isMine = message.senderId == _myId;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: OrderCard(order: order, myId: _myId),
        ),
      ),
    );
  }

  /// One message, like the website: mine on the right in light green,
  /// theirs on the left in white. The "tail" corner points to the sender.
  Widget _buildBubble(ChatMessage message) {
    final isMine = message.senderId == _myId;
    const round = Radius.circular(14);
    const tail = Radius.circular(4);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        // Bubbles use at most 82% of the width, like the website.
        widthFactor: 0.82,
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primaryLight : AppColors.surface,
              border: Border.all(
                color: isMine ? AppColors.primaryLight : AppColors.border,
              ),
              borderRadius: BorderRadius.only(
                topLeft: round,
                topRight: round,
                bottomLeft: isMine ? round : tail,
                bottomRight: isMine ? tail : round,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 15, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  formatTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The other person's id. A chat id is both user ids, sorted and joined
  /// with "_" (see MessageService.chatIdFor), so we remove ours.
  String get _otherId => widget.chatId
      .split('_')
      .firstWhere((id) => id != _myId, orElse: () => '');

  /// Farmers can offer a crop right in the chat, even one that is not in
  /// the Market.
  Future<void> _sendOffer() async {
    await showOfferSheet(
      context,
      chatId: widget.chatId,
      buyerId: _otherId,
      buyerName: widget.otherName,
    );
  }

  Widget _buildInputBar() {
    final isFarmer = AuthService.currentUser?.isFarmer ?? false;
    return SafeArea(
      child: Container(
        // White bar with a thin line on top (website .composer).
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          10,
          AppSizes.pagePadding,
          10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isFarmer) ...[
              Tooltip(
                message: 'Send an offer for a crop',
                child: SizedBox(
                  height: AppSizes.minTapTarget,
                  child: OutlinedButton.icon(
                    onPressed: _otherId.isEmpty ? null : _sendOffer,
                    icon: const Icon(Icons.local_offer_outlined, size: 18),
                    label: const Text('Offer'),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.small),
            ],
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Type a message'),
              ),
            ),
            const SizedBox(width: AppSizes.small),
            SizedBox(
              height: AppSizes.minTapTarget,
              child: FilledButton.icon(
                onPressed: _isSending ? null : _send,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
