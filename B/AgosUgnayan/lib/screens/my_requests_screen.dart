// F5 Buyer Requests: the buyer's own requests in two tabs, Open and Closed,
// with search, sorting and page numbers. A buyer can post, edit, close
// (found a farmer), reopen and delete requests. Closing is undoable from
// the message; deleting asks first and can be undone too.

import 'package:flutter/material.dart';

import '../models/buyer_request.dart';
import '../services/auth_service.dart';
import '../services/request_service.dart';
import '../utils/app_exception.dart';
import '../utils/paging.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/request_card.dart';
import 'request_detail_screen.dart';
import 'request_form_screen.dart';

enum _Sort { soonest, newest }

/// The logged-in buyer's crop requests.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final _service = RequestService();
  final _scroll = ScrollController();
  List<BuyerRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  RequestStatus _tab = RequestStatus.open;
  String _search = '';
  _Sort _sort = _Sort.soonest;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final requests = await _service.fetchByBuyer(AuthService.currentUser!.id);
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
  }

  Future<void> _openForm([BuyerRequest? request]) async {
    final wasExpired = request?.status == RequestStatus.expired;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RequestFormScreen(request: request)),
    );
    if (saved != true) return;
    await _load();
    // An expired request with a new date is open again; say so, with Undo.
    if (wasExpired && mounted) {
      showUndoMessage(
        context,
        '${request!.crop} request is open again. Farmers can see it.',
        onUndo: () async {
          await _service.restore(request); // back to the old date
          _load();
        },
      );
    }
  }

  /// Closes (after asking) or reopens a request, with Undo in the message.
  Future<void> _setClosed(BuyerRequest request, bool closed) async {
    if (closed) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Close this request?',
        message:
            'Farmers will no longer see your ${request.crop} request. '
            'You can reopen it from the Closed tab.',
        confirmLabel: 'Close request',
        isDestructive: false,
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await _service.setClosed(request.id, closed);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      showUndoMessage(
        context,
        closed
            ? '${request.crop} request closed. Farmers no longer see it.'
            : '${request.crop} request is open again.',
        onUndo: () async {
          await _service.setClosed(request.id, !closed);
          _load();
        },
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
  }

  Future<void> _delete(BuyerRequest request) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this request?',
      message: 'Farmers will no longer see your ${request.crop} request.',
      confirmLabel: AppStrings.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.delete(request.id);
      if (!mounted) return;
      setState(() => _requests.remove(request));
      showUndoMessage(
        context,
        'Request deleted.',
        onUndo: () async {
          await _service.restore(request);
          _load();
        },
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
  }

  List<BuyerRequest> get _visible {
    final list = _requests.where((r) {
      if (r.status != _tab) return false;
      return matchesSearch(_search, [r.crop, r.town, r.notes]);
    }).toList();
    if (_sort == _Sort.soonest) {
      list.sort((a, b) => a.neededBy.compareTo(b.neededBy));
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final slice = pageOf(visible, _page, pageSize: 10);
    int count(RequestStatus status) =>
        _requests.where((r) => r.status == status).length;
    final expired = count(RequestStatus.expired);
    return ListPage(
      controller: _scroll,
      onRefresh: _load,
      header: PageHeader(
        eyebrow: 'What you need',
        title: 'My requests',
        help: const [
          'Post a request to tell farmers what you need. They can message you.',
          'When you found a farmer, use "Close request" so farmers stop offering.',
          'When the "needed by" date passes, a request becomes Expired: '
              'farmers stop seeing it. Choose a new date to open it again, or '
              'close it.',
        ],
        lead: 'Farmers see open requests in Buyer Demand and can message you.',
        trailing: FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Post request'),
        ),
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusTabs<RequestStatus>(
            value: _tab,
            labels: const {
              RequestStatus.open: 'Open',
              RequestStatus.expired: 'Expired',
              RequestStatus.closed: 'Closed',
            },
            counts: {
              for (final status in RequestStatus.values) status: count(status),
            },
            onChanged: (tab) => _update(() => _tab = tab),
          ),
          // Expired requests need the buyer: say so on every tab.
          if (expired > 0 && _tab != RequestStatus.expired) ...[
            const SizedBox(height: 10),
            NoticeBox(
              kind: NoticeKind.warning,
              message:
                  '$expired request${expired == 1 ? ' has' : 's have'} expired. '
                  'Open the Expired tab to choose a new date or close '
                  '${expired == 1 ? 'it' : 'them'}.',
            ),
          ],
          const SizedBox(height: 10),
          ListToolbar(
            search: SearchBox(
              hint: 'Search crop, town, notes…',
              onChanged: (text) => _update(() => _search = text),
            ),
            sort: SortMenu<_Sort>(
              value: _sort,
              options: const {
                _Sort.soonest: 'Needed soonest',
                _Sort.newest: 'Newest',
              },
              onChanged: (sort) => _update(() => _sort = sort),
            ),
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: visible.isEmpty,
      emptyMessage: _search.isNotEmpty
          ? 'No requests match "$_search".'
          : switch (_tab) {
              RequestStatus.open =>
                'No open requests.\nTap "Post request" to tell farmers what '
                    'you need.',
              RequestStatus.expired =>
                'No expired requests. Requests expire when their "needed by" '
                    'date passes.',
              RequestStatus.closed =>
                'No closed requests. Close a request when you found a farmer.',
            },
      sliverBuilder: (context, width) => sliverCardGrid(
        contentWidth: width,
        count: slice.items.length,
        minTileWidth: 420,
        maxColumns: 2,
        tileHeight: 132,
        itemBuilder: (context, index) => _card(slice.items[index]),
      ),
      pagination: PaginationBar(slice: slice, onPage: _goToPage),
    );
  }

  Widget _card(BuyerRequest request) {
    return RequestCard(
      request: request,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(request: request),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More actions',
        onSelected: (action) => switch (action) {
          'edit' || 'newdate' => _openForm(request),
          'close' => _setClosed(request, true),
          'reopen' => _setClosed(request, false),
          _ => _delete(request),
        },
        itemBuilder: (_) => [
          if (request.status == RequestStatus.expired)
            const PopupMenuItem(
              value: 'newdate',
              child: Text('Choose a new date'),
            )
          else
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (request.status != RequestStatus.closed)
            PopupMenuItem(
              value: 'close',
              child: Text(
                request.status == RequestStatus.expired
                    ? 'Close (no longer needed)'
                    : 'Close request (found a farmer)',
              ),
            ),
          // Reopen only while its date has not passed; otherwise pick a new
          // date with Edit.
          if (request.status == RequestStatus.closed && request.daysLeft >= 0)
            const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
