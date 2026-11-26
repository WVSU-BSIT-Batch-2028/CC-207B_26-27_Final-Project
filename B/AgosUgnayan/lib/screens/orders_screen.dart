// Orders: every deal of the logged-in farmer (their sales) or buyer (their
// orders), from Market requests and from private chat offers. The list is
// live (one Firestore query), with tabs, search, sort and pages like the
// other list screens. The buttons on each card move the order along.

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../utils/paging.dart';
import '../utils/strings.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/order_card.dart';
import '../widgets/page_header.dart';
import 'chat_screen.dart';

/// The four tabs, grouping the order states.
enum OrdersTab { waiting, reserved, sold, closed }

/// Which tab an order belongs in.
OrdersTab tabOf(OrderState state) => switch (state) {
  OrderState.pending || OrderState.offered => OrdersTab.waiting,
  OrderState.reserved || OrderState.holdEnded => OrdersTab.reserved,
  OrderState.completed => OrdersTab.sold,
  _ => OrdersTab.closed,
};

enum _Sort { newest, total }

/// The Orders tab for farmers ("Sales") and buyers ("My orders").
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _service = OrderService();
  final _scroll = ScrollController();
  final _me = AuthService.currentUser!;
  StreamSubscription<List<CropOrder>>? _subscription;
  List<CropOrder> _orders = [];
  bool _isLoading = true;
  String? _error;

  OrdersTab _tab = OrdersTab.waiting;
  String _search = '';
  _Sort _sort = _Sort.newest;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Starts (or restarts, for Retry) the live list of my orders.
  void _listen() {
    _subscription?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _subscription = _service
        .watchMine(_me.id)
        .listen(
          (orders) {
            if (!mounted) return;
            setState(() {
              _orders = orders;
              _isLoading = false;
            });
            // Farmers free stock still held for offers the buyer declined
            // or never answered (buyers may not write the listing).
            if (_me.isFarmer) _service.releaseClosedHolds(orders);
          },
          onError: (_) {
            if (mounted) {
              setState(() {
                _error = AppStrings.networkError;
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _refresh() async => _listen();

  void _update(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
  }

  List<CropOrder> get _visible {
    final now = DateTime.now();
    final list = _orders.where((o) {
      if (tabOf(o.stateAt(now)) != _tab) return false;
      return matchesSearch(_search, [
        o.crop,
        o.title,
        o.buyerName,
        o.farmerName,
        o.note,
      ]);
    }).toList();
    if (_sort == _Sort.total) {
      list.sort((a, b) => b.total.compareTo(a.total));
    }
    return list; // already newest first
  }

  void _openChat(CropOrder order) {
    final isFarmer = order.farmerId == _me.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: order.chatId,
          otherName: isFarmer ? order.buyerName : order.farmerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = _visible;
    final slice = pageOf(visible, _page, pageSize: 10);
    int count(OrdersTab tab) =>
        _orders.where((o) => tabOf(o.stateAt(now)) == tab).length;
    final isFarmer = _me.isFarmer;
    return ListPage(
      controller: _scroll,
      onRefresh: _refresh,
      header: PageHeader(
        eyebrow: isFarmer ? 'Your sales' : 'What you are buying',
        title: isFarmer ? 'Orders' : 'My orders',
        lead: isFarmer
            ? 'Requests from the Market and offers you sent in chats.'
            : 'Your requests to buy and the offers farmers sent you.',
        help: [
          'Waiting: a request or offer nobody has answered yet. Nothing is '
              'held for the buyer yet.',
          'Reserved: the farmer holds the stock for the buyer for 3 days. '
              'The farmer can hold it 3 more days, mark it as sold, or '
              'cancel it.',
          'Requests and offers expire after 3 days without an answer.',
          '"Private offer" means it was offered in a chat and is not in the '
              'Market.',
        ],
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusTabs<OrdersTab>(
            value: _tab,
            labels: const {
              OrdersTab.waiting: 'Waiting',
              OrdersTab.reserved: 'Reserved',
              OrdersTab.sold: 'Sold',
              OrdersTab.closed: 'Closed',
            },
            counts: {for (final tab in OrdersTab.values) tab: count(tab)},
            onChanged: (tab) => _update(() => _tab = tab),
          ),
          const SizedBox(height: 10),
          ListToolbar(
            search: SearchBox(
              hint: isFarmer
                  ? 'Search crop or buyer…'
                  : 'Search crop or farmer…',
              onChanged: (text) => _update(() => _search = text),
            ),
            sort: SortMenu<_Sort>(
              value: _sort,
              options: const {
                _Sort.newest: 'Newest',
                _Sort.total: 'Biggest total',
              },
              onChanged: (sort) => _update(() => _sort = sort),
            ),
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _listen,
      isEmpty: visible.isEmpty,
      emptyMessage: _search.isNotEmpty
          ? 'No orders match "$_search".'
          : switch (_tab) {
              OrdersTab.waiting =>
                isFarmer
                    ? 'No requests waiting. Buyers ask from your Market '
                          'listings, or send an offer in a chat.'
                    : 'Nothing waiting. Open a crop in the Market and tap '
                          '"Request to buy".',
              OrdersTab.reserved => 'Nothing is reserved right now.',
              OrdersTab.sold => 'No sales yet.',
              OrdersTab.closed => 'No declined, cancelled or expired orders.',
            },
      sliverBuilder: (context, width) => SliverConstrainedCrossAxis(
        maxExtent: 760,
        sliver: SliverList.separated(
          itemCount: slice.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = slice.items[index];
            return OrderCard(
              order: order,
              myId: _me.id,
              onOpenChat: order.chatId.isEmpty ? null : () => _openChat(order),
            );
          },
        ),
      ),
      pagination: PaginationBar(slice: slice, onPage: _goToPage),
    );
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }
}
