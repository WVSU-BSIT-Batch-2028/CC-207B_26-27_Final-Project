// F2 Marketplace: buyers browse crops for sale. Search, town, crop, a
// min/max price filter, sorting and page numbers all work together:
// 1. Firestore returns the newest 100 crops for sale (crop and town filters
//    are part of that query).
// 2. On the phone we apply the search and price filter, sort, and cut the
//    result into pages of 12. Changing any filter goes back to page 1.

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../services/listing_service.dart';
import '../utils/strings.dart';
import '../utils/constants.dart';
import '../utils/paging.dart';
import '../widgets/chip_filter_row.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/listing_card.dart';
import '../widgets/page_header.dart';
import 'listing_detail_screen.dart';

/// The ways the buyer can order the crops.
enum MarketSort { newest, priceLow, priceHigh, quantity }

const Map<MarketSort, String> _sortLabels = {
  MarketSort.newest: 'Newest',
  MarketSort.priceLow: 'Lowest price',
  MarketSort.priceHigh: 'Highest price',
  MarketSort.quantity: 'Most available',
};

/// The buyer's Market tab.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _scroll = ScrollController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  List<Listing> _all = []; // what Firestore returned
  StreamSubscription<List<Listing>>? _subscription;
  bool _isLoading = true;
  String? _error;

  String _search = '';
  CropCategory? _category; // null = all categories
  String? _crop; // null = all crops (of the category)
  String? _town; // null = all towns
  double? _minPrice;
  double? _maxPrice;
  MarketSort _sort = MarketSort.newest;
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
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  /// Starts the live Market list for the chosen crop and town. It updates
  /// by itself, e.g. when a crop becomes fully reserved or comes back.
  Future<void> _load() async {
    _subscription?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _subscription = ListingService()
        .watchForMarket(crop: _crop, town: _town)
        .listen(
          (listings) {
            if (mounted) {
              setState(() {
                _all = listings;
                _isLoading = false;
              });
            }
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

  /// Every filter change starts again at page 1 (so nobody lands on an
  /// empty page 3).
  void _update(VoidCallback change, {bool reload = false}) {
    setState(() {
      change();
      _page = 1;
    });
    if (reload) _load();
  }

  bool get _isFiltered =>
      _search.isNotEmpty ||
      _category != null ||
      _crop != null ||
      _town != null ||
      _minPrice != null ||
      _maxPrice != null;

  void _clearAll() {
    _minController.clear();
    _maxController.clear();
    _update(() {
      _search = '';
      _category = null;
      _crop = null;
      _town = null;
      _minPrice = null;
      _maxPrice = null;
    }, reload: true);
  }

  /// The loaded crops after search and price filter, in the chosen order.
  List<Listing> get _visible {
    final list = _all.where((listing) {
      // A category without a chosen crop shows every crop of that category.
      if (_category != null && cropInfo(listing.crop)?.category != _category) {
        return false;
      }
      if (_minPrice != null && listing.price < _minPrice!) return false;
      if (_maxPrice != null && listing.price > _maxPrice!) return false;
      return matchesSearch(_search, [
        listing.title,
        listing.crop,
        listing.farmerName,
        listing.town,
        listing.description,
      ]);
    }).toList();
    switch (_sort) {
      case MarketSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case MarketSort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case MarketSort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case MarketSort.quantity:
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
    }
    return list;
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    // Back to the top so the new page starts where the eye is.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final slice = pageOf(visible, _page);
    return ListPage(
      controller: _scroll,
      onRefresh: _load,
      header: const PageHeader(
        eyebrow: 'Fresh from Iloilo farms',
        title: 'Market',
        help: [
          'Type in the search box to find a crop, farmer or town.',
          'Pick a town, a crop chip or a price range to narrow the list. "Clear all filters" starts over.',
          'Use Sort to see the cheapest or the newest crops first.',
          'Tap a crop to see details, message the farmer or follow it.',
        ],
        lead: 'Crops for sale by local farmers. Tap one to see details.',
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            search: SearchBox(
              hint: 'Search crop, farmer, town…',
              onChanged: (text) => _update(() => _search = text),
            ),
            filters: [
              FilterDropdown(
                value: _crop,
                allLabel: 'All crops',
                options: _category == null ? kCrops : cropsIn(_category!),
                icon: Icons.eco_outlined,
                width: 168,
                onChanged: (crop) => _update(() => _crop = crop, reload: true),
              ),
              FilterDropdown(
                value: _town,
                allLabel: 'All towns',
                options: kTowns,
                icon: Icons.place_outlined,
                width: 152,
                onChanged: (town) => _update(() => _town = town, reload: true),
              ),
              _priceField(_minController, 'Min ₱', (v) => _minPrice = v),
              _priceField(_maxController, 'Max ₱', (v) => _maxPrice = v),
            ],
            sort: SortMenu<MarketSort>(
              value: _sort,
              options: _sortLabels,
              onChanged: (sort) => _update(() => _sort = sort),
            ),
            resultText: _isLoading
                ? null
                : '${visible.length} crop${visible.length == 1 ? '' : 's'} '
                      'found',
            onClearAll: _isFiltered ? _clearAll : null,
          ),
          const SizedBox(height: 10),
          CategoryChipRow(
            selected: _category,
            onSelected: (category) => _update(() {
              _category = category;
              // A crop from another category would hide everything.
              if (_crop != null && cropInfo(_crop!)?.category != category) {
                _crop = null;
              }
            }, reload: true),
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: visible.isEmpty,
      emptyMessage: _isFiltered
          ? 'No crops match your search and filters.\n'
                'Try fewer filters, or tap "Clear all filters".'
          : 'No crops for sale yet. Check again soon.',
      sliverBuilder: (context, width) => sliverCardGrid(
        contentWidth: width,
        count: slice.items.length,
        minTileWidth: 210,
        minColumns: 2,
        maxColumns: 5,
        // Photo area (16:10) plus room for the text below it.
        tileHeightFor: (tileWidth) => tileWidth * 10 / 16 + 112,
        itemBuilder: (context, index) {
          final listing = slice.items[index];
          return ListingGridCard(
            listing: listing,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(listing: listing),
              ),
            ),
          );
        },
      ),
      pagination: PaginationBar(slice: slice, onPage: _goToPage),
    );
  }

  /// A small number box for the min or max price. An empty or invalid box
  /// means "no limit".
  Widget _priceField(
    TextEditingController controller,
    String hint,
    void Function(double?) set,
  ) {
    return SizedBox(
      // Narrow, so town + min + max fit in one row on a phone.
      width: 86,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: hint, isDense: true),
        onChanged: (text) => _update(() => set(double.tryParse(text.trim()))),
      ),
    );
  }
}
