// The farmer's Home tab (like the website's seller dashboard): a greeting,
// four numbers that matter, buyer requests for the farmer's own crops, the
// newest PSA prices and the farmer's latest listings. Every block links to
// the page with the details, so the first screen already helps the farmer
// decide what to do next.

import 'package:flutter/material.dart';

import '../models/buyer_request.dart';
import '../models/listing.dart';
import '../models/price_record.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../services/price_service.dart';
import '../services/request_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/home_nav.dart';
import '../widgets/listing_card.dart';
import '../widgets/page_header.dart';
import '../widgets/price_mini_list.dart';
import '../widgets/request_card.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import 'crop_form_screen.dart';
import 'listing_detail_screen.dart';
import 'request_detail_screen.dart';

/// Farmer dashboard.
class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  List<Listing> _myListings = [];
  List<BuyerRequest> _openRequests = [];
  List<PriceRecord> _prices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the three things the dashboard shows, all at the same time.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final me = AuthService.currentUser!;
      final results = await Future.wait([
        ListingService().fetchByFarmer(me.id),
        RequestService().fetchOpen(),
        PriceService().fetchRecent(),
      ]);
      if (!mounted) return;
      setState(() {
        // Only crops still for sale count as "selling".
        _myListings = (results[0] as List<Listing>)
            .where((l) => l.isActive)
            .toList();
        _openRequests = results[1] as List<BuyerRequest>;
        _prices = (results[2] as PriceData).records;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addCrop() async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CropFormScreen()));
    if (saved == true) _load();
  }

  void _open(HomeTab tab) => HomeNav.of(context)?.open(tab);

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser!;
    final firstName = me.name.split(' ').first;
    return RefreshIndicator(
      onRefresh: _load,
      child: AsyncStateView(
        isLoading: _isLoading,
        errorMessage: _error,
        onRetry: _load,
        isEmpty: false,
        emptyMessage: '',
        builder: (context) => ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    eyebrow: me.town.isEmpty
                        ? 'Iloilo Province'
                        : '${me.town}, Iloilo',
                    title: 'Hello, $firstName',
                    lead: 'Here is what is happening with your crops.',
                    trailing: FilledButton.icon(
                      onPressed: _addCrop,
                      icon: const Icon(Icons.add),
                      label: const Text('Add crop'),
                    ),
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  _buildStats(),
                  const SizedBox(height: AppSizes.sectionGap),
                  _buildColumns(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// My crops this farmer sells.
  Set<String> get _myCrops => {for (final l in _myListings) l.crop};

  /// Open buyer requests for crops this farmer sells.
  List<BuyerRequest> get _demandForMe =>
      _openRequests.where((r) => _myCrops.contains(r.crop)).toList();

  Widget _buildStats() {
    final newest = _prices.isEmpty
        ? null
        : _prices
              .map((p) => p.month)
              .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    return StatGrid(
      tiles: [
        StatTile(
          icon: Icons.campaign_outlined,
          value: '${_demandForMe.length}',
          label: 'Buyer requests for your crops',
          highlight: true,
          onTap: () => _open(HomeTab.demand),
        ),
        StatTile(
          icon: Icons.grass_outlined,
          value: '${_myListings.length}',
          label: 'Crops you are selling',
          onTap: () => _open(HomeTab.myCrops),
        ),
        StatTile(
          icon: Icons.assignment_outlined,
          value: '${_openRequests.length}',
          label: 'Open buyer requests in Iloilo',
          onTap: () => _open(HomeTab.demand),
        ),
        StatTile(
          icon: Icons.trending_up,
          value: newest == null ? '–' : formatMonthKey(newest),
          label: 'Newest PSA price month',
          onTap: () => _open(HomeTab.prices),
        ),
      ],
    );
  }

  /// Two columns on a wide screen, one below the other on a phone.
  Widget _buildColumns() {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildDemand(), const SizedBox(height: 14), _buildMyCrops()],
    );
    final right = _buildPrices();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: right),
          ],
        );
      },
    );
  }

  Widget _buildDemand() {
    // Requests for my crops first; if there are none, the soonest of all.
    final mine = _demandForMe;
    final shown = (mine.isNotEmpty ? mine : _openRequests).take(4).toList();
    return SectionCard(
      icon: Icons.campaign_outlined,
      title: mine.isNotEmpty
          ? 'Buyers want your crops'
          : 'Buyer requests in Iloilo',
      action: TextButton(
        onPressed: () => _open(HomeTab.demand),
        child: const Text('See all'),
      ),
      child: shown.isEmpty
          ? const Text(
              'No open buyer requests right now.',
              style: AppTextStyles.lead,
            )
          : Column(
              children: [
                for (final request in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RequestCard(
                      request: request,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RequestDetailScreen(request: request),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildMyCrops() {
    final latest = _myListings.take(3).toList();
    return SectionCard(
      icon: Icons.grass_outlined,
      title: 'Your latest crops',
      action: TextButton(
        onPressed: () => _open(HomeTab.myCrops),
        child: const Text('Manage'),
      ),
      child: latest.isEmpty
          ? Row(
              children: [
                const Expanded(
                  child: Text(
                    'You have no crops for sale yet.',
                    style: AppTextStyles.lead,
                  ),
                ),
                OutlinedButton(
                  onPressed: _addCrop,
                  child: const Text('Add crop'),
                ),
              ],
            )
          : Column(
              children: [
                for (final listing in latest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListingCard(
                      listing: listing,
                      showFarmer: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listing: listing),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPrices() {
    // Prices of the crops I sell first, then the rest, up to 6.
    final crops = [
      ..._myCrops,
      ...kCrops.where((crop) => !_myCrops.contains(crop)),
    ].take(6).toList();
    return SectionCard(
      icon: Icons.trending_up,
      title: 'PSA farmgate prices',
      padChild: false,
      action: TextButton(
        onPressed: () => _open(HomeTab.prices),
        child: const Text('All prices'),
      ),
      child: PriceMiniList(crops: crops, records: _prices),
    );
  }
}
