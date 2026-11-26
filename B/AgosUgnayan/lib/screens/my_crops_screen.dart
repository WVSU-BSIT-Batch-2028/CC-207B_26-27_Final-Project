// F1 Crop Listings: the farmer's own listings in three tabs, like the
// website: Active (buyers see them), Sold out, and Removed. Each crop has
// a menu: Edit, Mark as sold out / Put back on sale, Remove / Restore, and
// (only in Removed) Delete forever. Search, sorting and page numbers work
// inside the chosen tab.

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../services/auth_service.dart';
import '../services/listing_photo_service.dart';
import '../services/listing_service.dart';
import '../utils/app_exception.dart';
import '../utils/format.dart';
import '../utils/paging.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/listing_card.dart';
import '../widgets/page_header.dart';
import 'crop_form_screen.dart';
import 'listing_detail_screen.dart';

enum _Sort { newest, priceHigh, priceLow, name }

const Map<String, String> _tabLabels = {
  ListingStatus.active: 'Active',
  ListingStatus.sold: 'Sold out',
  ListingStatus.removed: 'Removed',
};

/// The logged-in farmer's crop listings.
class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({super.key});

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  final _service = ListingService();
  final _scroll = ScrollController();
  List<Listing> _listings = [];
  StreamSubscription<List<Listing>>? _subscription;
  bool _isLoading = true;
  String? _error;

  String _tab = ListingStatus.active;
  String _search = '';
  _Sort _sort = _Sort.newest;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Starts (or restarts, for Retry) the live list of my crops. It stays
  /// current when stock is held or sold in Orders.
  Future<void> _load() async {
    _subscription?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _subscription = _service
        .watchByFarmer(AuthService.currentUser!.id)
        .listen(
          (listings) {
            if (!mounted) return;
            setState(() {
              _listings = listings;
              _isLoading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _error = AppStrings.networkError;
              _isLoading = false;
            });
          },
        );
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
  }

  /// Opens the form (empty for a new crop) and reloads if something was saved.
  Future<void> _openForm([Listing? listing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CropFormScreen(listing: listing)),
    );
    if (saved == true) _load();
  }

  /// Moves a listing to another tab (sold out, removed, back on sale), with
  /// Undo in the message. Nothing is lost, so no question first.
  Future<void> _setStatus(Listing listing, String status, String done) async {
    final before = listing.status;
    // Stock held for buyers must be sold or cancelled first, so nobody
    // loses a reservation without being told (see Orders).
    final held = listing.reserved;
    if (status != ListingStatus.active && held > 0) {
      showError(
        context,
        '${formatQuantity(held)} ${listing.unit} is reserved for buyers. '
        'Mark those orders as sold or cancel them in Orders first.',
      );
      return;
    }
    try {
      await _service.setStatus(listing.id, status);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      showUndoMessage(
        context,
        done,
        onUndo: () async {
          await _service.setStatus(listing.id, before);
          _load();
        },
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
  }

  /// Deleting forever is only offered for removed crops, and asks first.
  Future<void> _delete(Listing listing) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this crop forever?',
      message:
          '${listing.headline} will be deleted. You can still undo it right '
          'after, from the message at the bottom.',
      confirmLabel: AppStrings.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      // Keep the photo in memory first, so Undo can put it back.
      final photo = listing.photoId == null
          ? null
          : await ListingPhotoService.instance.photoFor(listing.id);
      await _service.delete(listing);
      if (!mounted) return;
      setState(() => _listings.remove(listing));
      showUndoMessage(
        context,
        '${listing.headline} deleted.',
        onUndo: () async {
          await _service.restore(listing, photo: photo);
          _load();
        },
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
  }

  List<Listing> get _visible {
    final list = _listings.where((listing) {
      if (listing.status != _tab) return false;
      return matchesSearch(_search, [
        listing.title,
        listing.crop,
        listing.town,
        listing.description,
      ]);
    }).toList();
    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _Sort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.name:
        list.sort((a, b) => a.crop.compareTo(b.crop));
    }
    return list;
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser!;
    final visible = _visible;
    final slice = pageOf(visible, _page, pageSize: 10);
    return ListPage(
      controller: _scroll,
      onRefresh: _load,
      header: PageHeader(
        eyebrow: user.town.isEmpty ? 'Your farm' : '${user.town}, Iloilo',
        title: 'My crops',
        help: const [
          'Active crops are shown to buyers in the Market.',
          'Use the menu on a crop to edit it, mark it sold out, or remove it.',
          'The line under each crop shows how much is available, reserved '
              'for buyers, and sold. Reserved stock is managed in Orders.',
          'Sold out and removed crops are kept, so you can put them back on sale.',
          'Every change has Undo in the message at the bottom.',
        ],
        lead: 'Buyers see your Active crops in the Market.',
        trailing: FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add crop'),
        ),
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusTabs<String>(
            value: _tab,
            labels: _tabLabels,
            counts: {
              for (final status in _tabLabels.keys)
                status: _listings.where((l) => l.status == status).length,
            },
            onChanged: (tab) => _update(() => _tab = tab),
          ),
          const SizedBox(height: 10),
          ListToolbar(
            search: SearchBox(
              hint: 'Search your crops…',
              onChanged: (text) => _update(() => _search = text),
            ),
            sort: SortMenu<_Sort>(
              value: _sort,
              options: const {
                _Sort.newest: 'Newest',
                _Sort.priceHigh: 'Highest price',
                _Sort.priceLow: 'Lowest price',
                _Sort.name: 'Crop name (A-Z)',
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
          ? 'No crops match "$_search".'
          : switch (_tab) {
              ListingStatus.active =>
                'No crops for sale yet.\nTap "Add crop" to sell one.',
              ListingStatus.sold =>
                'Nothing sold out. Use "Mark as sold out" in a crop\'s menu '
                    'when it is gone.',
              _ => 'Nothing removed. Removed crops can be restored here.',
            },
      sliverBuilder: (context, width) => sliverCardGrid(
        contentWidth: width,
        count: slice.items.length,
        minTileWidth: 420,
        maxColumns: 2,
        tileHeight: 120,
        itemBuilder: (context, index) => _card(slice.items[index]),
      ),
      pagination: PaginationBar(slice: slice, onPage: _goToPage),
    );
  }

  Widget _card(Listing listing) {
    final crop = listing.crop;
    return ListingCard(
      listing: listing,
      showFarmer: false,
      showStock: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listing: listing),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More actions',
        onSelected: (action) => switch (action) {
          'edit' => _openForm(listing),
          'sold' => _setStatus(
            listing,
            ListingStatus.sold,
            '$crop marked as sold out. Buyers no longer see it.',
          ),
          'active' => _setStatus(
            listing,
            ListingStatus.active,
            '$crop is for sale again.',
          ),
          'remove' => _setStatus(
            listing,
            ListingStatus.removed,
            '$crop removed. Restore it from the Removed tab.',
          ),
          _ => _delete(listing),
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (listing.status == ListingStatus.active)
            const PopupMenuItem(value: 'sold', child: Text('Mark as sold out')),
          if (listing.status != ListingStatus.active)
            PopupMenuItem(
              value: 'active',
              child: Text(
                listing.status == ListingStatus.removed
                    ? 'Restore (put on sale)'
                    : 'Put back on sale',
              ),
            ),
          if (listing.status != ListingStatus.removed)
            const PopupMenuItem(value: 'remove', child: Text('Remove')),
          if (listing.status == ListingStatus.removed)
            const PopupMenuItem(value: 'delete', child: Text('Delete forever')),
        ],
      ),
    );
  }
}
