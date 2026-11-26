// F5 Buyer Requests, farmer side: "Buyer Demand" lists what buyers need.
// Search, crop chips, a town filter, "Only my crops", sorting and page
// numbers all work together on the open requests loaded from Firestore.

import 'package:flutter/material.dart';

import '../models/buyer_request.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../services/request_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/paging.dart';
import '../widgets/chip_filter_row.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/page_header.dart';
import '../widgets/request_card.dart';
import 'request_detail_screen.dart';

/// The ways a farmer can order the requests.
enum DemandSort { soonest, newest, biggest, bestPrice }

const Map<DemandSort, String> _sortLabels = {
  DemandSort.soonest: 'Needed soonest',
  DemandSort.newest: 'Newest',
  DemandSort.biggest: 'Largest amount',
  DemandSort.bestPrice: 'Highest target price',
};

/// Open buyer requests for farmers.
class BuyerDemandScreen extends StatefulWidget {
  const BuyerDemandScreen({super.key});

  @override
  State<BuyerDemandScreen> createState() => _BuyerDemandScreenState();
}

class _BuyerDemandScreenState extends State<BuyerDemandScreen> {
  final _scroll = ScrollController();
  List<BuyerRequest> _requests = [];
  Set<String> _myCrops = {};
  bool _isLoading = true;
  String? _error;

  String _search = '';
  CropCategory? _category; // null = all categories
  String? _crop; // null = all crops (of the category)
  String? _town; // null = all towns
  bool _onlyMine = false; // only crops this farmer sells
  DemandSort _sort = DemandSort.soonest;
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
      final me = AuthService.currentUser!;
      final results = await Future.wait([
        RequestService().fetchOpen(),
        ListingService().fetchByFarmer(me.id),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<BuyerRequest>;
        _myCrops = {
          for (final l in results[1] as List)
            if (l.isActive as bool) l.crop as String,
        };
      });
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

  bool get _isFiltered =>
      _search.isNotEmpty ||
      _category != null ||
      _crop != null ||
      _town != null ||
      _onlyMine;

  void _clearAll() => _update(() {
    _search = '';
    _category = null;
    _crop = null;
    _town = null;
    _onlyMine = false;
  });

  List<BuyerRequest> get _visible {
    final list = _requests.where((r) {
      if (_crop != null && r.crop != _crop) return false;
      if (_category != null && cropInfo(r.crop)?.category != _category) {
        return false;
      }
      if (_town != null && r.town != _town) return false;
      if (_onlyMine && !_myCrops.contains(r.crop)) return false;
      return matchesSearch(_search, [r.crop, r.town, r.buyerName, r.notes]);
    }).toList();
    switch (_sort) {
      case DemandSort.soonest:
        list.sort((a, b) => a.neededBy.compareTo(b.neededBy));
      case DemandSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case DemandSort.biggest:
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
      case DemandSort.bestPrice:
        // Requests without a target price go last.
        list.sort(
          (a, b) => (b.targetPrice ?? -1).compareTo(a.targetPrice ?? -1),
        );
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
    return ListPage(
      controller: _scroll,
      onRefresh: _load,
      header: PageHeader(
        eyebrow: 'Buyers in Iloilo',
        title: 'Buyer demand',
        help: const [
          'These are crops buyers in Iloilo are looking for, soonest first.',
          'Turn on "Only crops I sell" to see requests for the crops in My Crops.',
          'Tap a request, then "Message buyer" to offer your crop.',
        ],
        lead: _isLoading
            ? 'What local buyers are looking for.'
            : '${_requests.length} open request'
                  '${_requests.length == 1 ? '' : 's'}. Message a buyer to '
                  'offer your crop.',
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            search: SearchBox(
              hint: 'Search crop, town, buyer…',
              onChanged: (text) => _update(() => _search = text),
            ),
            filters: [
              FilterDropdown(
                value: _crop,
                allLabel: 'All crops',
                options: _category == null ? kCrops : cropsIn(_category!),
                icon: Icons.eco_outlined,
                width: 168,
                onChanged: (crop) => _update(() => _crop = crop),
              ),
              FilterDropdown(
                value: _town,
                allLabel: 'All towns',
                options: kTowns,
                icon: Icons.place_outlined,
                onChanged: (town) => _update(() => _town = town),
              ),
              if (_myCrops.isNotEmpty)
                FilterChip(
                  label: const Text('Only crops I sell'),
                  selected: _onlyMine,
                  showCheckmark: false,
                  onSelected: (value) => _update(() => _onlyMine = value),
                ),
            ],
            sort: SortMenu<DemandSort>(
              value: _sort,
              options: _sortLabels,
              onChanged: (sort) => _update(() => _sort = sort),
            ),
            resultText: _isLoading
                ? null
                : '${visible.length} request${visible.length == 1 ? '' : 's'}'
                      ' found',
            onClearAll: _isFiltered ? _clearAll : null,
          ),
          const SizedBox(height: 10),
          CategoryChipRow(
            selected: _category,
            onSelected: (category) => _update(() {
              _category = category;
              if (_crop != null && cropInfo(_crop!)?.category != category) {
                _crop = null;
              }
            }),
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: visible.isEmpty,
      emptyMessage: _isFiltered
          ? 'No requests match your search and filters.\n'
                'Tap "Clear all filters" to see every request.'
          : 'No buyer requests right now. Pull down to refresh.',
      sliverBuilder: (context, width) => sliverCardGrid(
        contentWidth: width,
        count: slice.items.length,
        minTileWidth: 420,
        maxColumns: 2,
        tileHeight: 132,
        itemBuilder: (context, index) {
          final request = slice.items[index];
          return RequestCard(
            request: request,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RequestDetailScreen(request: request),
              ),
            ),
          );
        },
      ),
      pagination: PaginationBar(slice: slice, onPage: _goToPage),
    );
  }
}
