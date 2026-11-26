// How one order looks, in the Orders screen and inside the chat. It shows
// what, how much, the total, a status label in words, where it came from
// (Marketplace or Private offer) and the buttons that fit the user's role
// and the order's state. Every button that can't be undone asks first.

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/message_service.dart';
import '../services/order_service.dart';
import '../utils/app_exception.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import 'confirm_dialog.dart';
import 'crop_thumb.dart';
import 'status_badge.dart';

/// The status label of an order, in words a farmer or buyer understands.
/// It is written from the viewer's side: what waits for me says "Needs your
/// answer", what waits for the other person says who we wait for.
class OrderStateBadge extends StatelessWidget {
  const OrderStateBadge({
    super.key,
    required this.state,
    required this.isFarmer,
  });

  final OrderState state;
  final bool isFarmer;

  @override
  Widget build(BuildContext context) {
    const yourTurn = ('Needs your answer', StatusKind.expired);
    final (label, kind) = switch (state) {
      OrderState.pending =>
        isFarmer ? yourTurn : ('Waiting for farmer', StatusKind.answered),
      OrderState.offered =>
        isFarmer ? ('Waiting for buyer', StatusKind.answered) : yourTurn,
      OrderState.reserved => ('Reserved', StatusKind.open),
      OrderState.holdEnded => ('Reservation ended', StatusKind.expired),
      OrderState.completed => ('Sold', StatusKind.open),
      OrderState.declined => ('Declined', StatusKind.closed),
      OrderState.cancelled => ('Cancelled', StatusKind.closed),
      OrderState.expired => ('Expired', StatusKind.expired),
    };
    return StatusBadge(label: label, kind: kind);
  }
}

/// One order with its buttons. [myId] decides which side's buttons show.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.myId,
    this.onOpenChat,
  });

  final CropOrder order;
  final String myId;

  /// Opens the conversation (null inside the chat itself).
  final VoidCallback? onOpenChat;

  bool get _isFarmer => order.farmerId == myId;

  @override
  Widget build(BuildContext context) {
    final state = order.state;
    final other = _isFarmer ? order.buyerName : order.farmerName;
    final amount = '${formatQuantity(order.qty)} ${order.unit}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CropThumb(crop: order.crop, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.crop}, $amount',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${formatPeso(order.price)}/${order.unit} · '
                        'Total ${formatPeso(order.total)}',
                        style: AppTextStyles.meta,
                      ),
                      Text(
                        '${_isFarmer ? 'Buyer' : 'Farmer'}: $other',
                        style: AppTextStyles.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.small),
                OrderStateBadge(state: state, isFarmer: _isFarmer),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SourceChip(order: order),
                Text(_whatNext(state), style: AppTextStyles.meta),
              ],
            ),
            if (order.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Note: ${order.note}', style: AppTextStyles.meta),
            ],
            _OrderButtons(
              order: order,
              state: state,
              isFarmer: _isFarmer,
              onOpenChat: onOpenChat,
            ),
          ],
        ),
      ),
    );
  }

  /// One line that says what happens next, from the user's side.
  String _whatNext(OrderState state) {
    final answerBy = formatDate(order.answerBy);
    final until = order.reservedUntil == null
        ? ''
        : formatDate(order.reservedUntil!);
    return switch (state) {
      OrderState.pending =>
        _isFarmer
            ? 'Accept to hold it for the buyer. Expires $answerBy.'
            : 'Nothing is held until the farmer accepts. Expires $answerBy.',
      OrderState.offered =>
        _isFarmer
            ? 'The buyer can accept until $answerBy.'
            : 'Accept to have it held for you. Expires $answerBy.',
      OrderState.reserved =>
        _isFarmer
            ? 'Held for the buyer until $until.'
            : 'The farmer is holding it for you until $until.',
      OrderState.holdEnded =>
        _isFarmer
            ? 'The hold ended on $until; the stock is free again.'
            : 'The hold ended on $until. Message the farmer.',
      OrderState.completed => 'Sold.',
      OrderState.declined => 'Declined.',
      OrderState.cancelled => 'Cancelled.',
      OrderState.expired => 'Nobody answered in time.',
    };
  }
}

/// "Marketplace" or "Private offer", so the two are easy to tell apart.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.order});

  final CropOrder order;

  @override
  Widget build(BuildContext context) {
    final private = order.isPrivateOffer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            private ? Icons.lock_outline : Icons.storefront_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            !private
                ? 'Marketplace'
                : order.usesListing
                ? 'Private offer · from listing'
                : 'Private offer',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The buttons that fit this side and state. Each one shows a spinner
/// while it works and a message when it is done.
class _OrderButtons extends StatefulWidget {
  const _OrderButtons({
    required this.order,
    required this.state,
    required this.isFarmer,
    this.onOpenChat,
  });

  final CropOrder order;
  final OrderState state;
  final bool isFarmer;
  final VoidCallback? onOpenChat;

  @override
  State<_OrderButtons> createState() => _OrderButtonsState();
}

class _OrderButtonsState extends State<_OrderButtons> {
  final _service = OrderService();
  bool _isBusy = false;

  CropOrder get _order => widget.order;
  String get _what =>
      '${formatQuantity(_order.qty)} ${_order.unit} of ${_order.crop}';

  /// Runs [action] after an optional question, then shows [done].
  Future<void> _run(
    Future<void> Function() action,
    String done, {
    String? askTitle,
    String? askMessage,
    String confirmLabel = 'Yes',
    bool destructive = true,
  }) async {
    if (askTitle != null) {
      final ok = await showConfirmDialog(
        context,
        title: askTitle,
        message: askMessage ?? '',
        confirmLabel: confirmLabel,
        cancelLabel: 'Keep it',
        isDestructive: destructive,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _isBusy = true);
    try {
      await action();
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      ..._actionsFor(widget.state),
      if (widget.onOpenChat != null)
        TextButton.icon(
          onPressed: widget.onOpenChat,
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Chat'),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _isBusy
          ? const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Wrap(spacing: 8, runSpacing: 4, children: buttons),
    );
  }

  List<Widget> _actionsFor(OrderState state) {
    final farmer = widget.isFarmer;
    if (farmer) {
      return switch (state) {
        OrderState.pending => [
          FilledButton(
            onPressed: () => _run(
              () => _service.accept(_order, byFarmer: true),
              'Accepted. $_what is held for the buyer.',
            ),
            child: const Text('Accept'),
          ),
          OutlinedButton(
            onPressed: () => _run(
              () => _service.decline(_order, byFarmer: true),
              'Request declined.',
              askTitle: 'Decline this request?',
              askMessage: 'The buyer will see that you declined $_what.',
              confirmLabel: 'Decline',
            ),
            child: const Text('Decline'),
          ),
        ],
        OrderState.offered => [
          OutlinedButton(
            onPressed: () => _run(
              () => _service.cancel(_order, byFarmer: true),
              'Offer cancelled.',
              askTitle: 'Cancel this offer?',
              askMessage: 'The buyer can no longer accept $_what.',
              confirmLabel: 'Cancel offer',
            ),
            child: const Text('Cancel offer'),
          ),
        ],
        OrderState.reserved || OrderState.holdEnded => [
          FilledButton(
            onPressed: () => _run(
              () => _service.markSold(_order),
              'Marked as sold.',
              askTitle: 'Mark as sold?',
              askMessage:
                  '$_what for ${formatPeso(_order.total)} will count as '
                  'sold. Do this after the buyer paid and picked it up.',
              confirmLabel: 'Mark as sold',
              destructive: false,
            ),
            child: const Text('Mark as sold'),
          ),
          OutlinedButton(
            onPressed: () =>
                _run(() => _service.extendHold(_order), 'Held 3 more days.'),
            child: const Text('Hold 3 more days'),
          ),
          TextButton(
            onPressed: () => _run(
              () => _service.cancel(_order, byFarmer: true),
              'Reservation cancelled. The stock is free again.',
              askTitle: 'Cancel this reservation?',
              askMessage:
                  '$_what goes back to your available stock and the buyer '
                  'is told in the chat.',
              confirmLabel: 'Cancel reservation',
            ),
            child: const Text('Cancel'),
          ),
        ],
        _ => const [],
      };
    }
    return switch (state) {
      OrderState.pending => [
        OutlinedButton(
          onPressed: () => _run(
            () => _service.cancel(_order, byFarmer: false),
            'Request cancelled.',
            askTitle: 'Cancel your request?',
            askMessage: 'The farmer will see that you no longer need $_what.',
            confirmLabel: 'Cancel request',
          ),
          child: const Text('Cancel request'),
        ),
      ],
      OrderState.offered => [
        FilledButton(
          onPressed: () => _run(
            () => _service.accept(_order, byFarmer: false),
            'Offer accepted. The farmer is holding it for you.',
            askTitle: 'Accept this offer?',
            askMessage:
                '$_what for ${formatPeso(_order.total)}. Agree on pickup '
                'and payment in the chat.',
            confirmLabel: 'Accept',
            destructive: false,
          ),
          child: const Text('Accept'),
        ),
        OutlinedButton(
          onPressed: () => _run(
            () => _service.decline(_order, byFarmer: false),
            'Offer declined.',
            askTitle: 'Decline this offer?',
            askMessage: 'The farmer will see that you declined $_what.',
            confirmLabel: 'Decline',
          ),
          child: const Text('Decline'),
        ),
      ],
      // The buyer can't touch the farmer's stock, so they ask in the chat.
      OrderState.reserved => [
        TextButton(
          onPressed: () => _run(
            () => MessageService().send(
              chatId: _order.chatId,
              senderId: _order.buyerId,
              text:
                  'Can we cancel my order of $_what? Please cancel the '
                  'reservation if that is OK.',
            ),
            'Message sent. The farmer can cancel the reservation.',
            askTitle: 'Ask the farmer to cancel?',
            askMessage:
                'Only the farmer can cancel a reservation. We will send '
                'them a message in the chat.',
            confirmLabel: 'Send message',
            destructive: false,
          ),
          child: const Text('Ask to cancel'),
        ),
      ],
      _ => const [],
    };
  }
}
