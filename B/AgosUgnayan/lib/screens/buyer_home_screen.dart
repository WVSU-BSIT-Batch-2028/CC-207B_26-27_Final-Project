// The buyer's Home tab (like the website's buyer dashboard): a greeting,
// the numbers that matter, the newest crops for sale, the buyer's own
// requests and this month's PSA prices. Each block links to its page.

import 'package:flutter/material.dart';

import '../models/buyer_request.dart';
import '../models/followed_item.dart';
import '../models/listing.dart';
import '../models/price_record.dart';
import '../services/auth_service.dart';
import '../services/following_service.dart';
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
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/price_mini_list.dart';
import '../widgets/request_card.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import 'listing_detail_screen.dart';
import 'request_detail_screen.dart';
import 'request_form_screen.dart';

/// Buyer dashboard.
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  List<Listing> _newest = [];
  bool _moreForSale = false;
  List<BuyerRequest> _myRequests = [];
  int _following = 0;
  List<PriceRecord> _prices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final me = AuthService.currentUser!;
      final results = await Future.wait([
        ListingService().fetchPage(),
        RequestService().fetchByBuyer(me.id),
        FollowingService().fetch(me.id, FollowType.listing),
        FollowingService().fetch(me.id, FollowType.farmer),
        PriceService().fetchRecent(),
      ]);
      if (!mounted) return;
      final page = results[0] as ListingPage;
      setState(() {
        // Only crops that are still for sale.
        _newest = page.listings
            .where((l) => l.isActive && l.available > 0)
            .toList();
        _moreForSale = page.hasMore;
        _myRequests = results[1] as List<BuyerRequest>;
        _following =
            (results[2] as List<FollowedItem>).length +
            (results[3] as List<FollowedItem>).length;
        _prices = (results[4] as PriceData).records;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _postRequest() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RequestFormScreen()));
    if (saved == true) _load();
  }

  void _open(HomeTab tab) => HomeNav.of(context)?.open(tab);

  /// The newest month with a PSA price, for the Prices tile.
  String? get _newestMonth => PriceService.newestMonth(_prices);

  List<BuyerRequest> get _openRequests =>
      _myRequests.where((r) => !r.isClosed).toList();

  /// The reminder about requests that expire soon or have expired (our
  /// in-app notification; push or email would need a paid server).
  Widget? _requestReminder() {
    final expired = _myRequests.where((r) => r.isExpired).length;
    final soon = _myRequests.where((r) => r.expiresSoon()).length;
    if (expired == 0 && soon == 0) return null;
    final parts = [
      if (soon > 0)
        '$soon request${soon == 1 ? ' expires' : 's expire'} today or tomorrow',
      if (expired > 0)
        '$expired request${expired == 1 ? ' has' : 's have'} expired',
    ];
    return Row(
      children: [
        Expanded(
          child: NoticeBox(
            kind: NoticeKind.warning,
            message:
                '${parts.join(' and ')}. Choose a new date or close '
                '${expired + soon == 1 ? 'it' : 'them'} in My requests.',
          ),
        ),
        const SizedBox(width: AppSizes.small),
        TextButton(
          onPressed: () => _open(HomeTab.requests),
          child: const Text('Review'),
        ),
      ],
    );
  }

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
                    lead: 'Fresh crops from local farmers, and your requests.',
                    trailing: FilledButton.icon(
                      onPressed: _postRequest,
                      icon: const Icon(Icons.add),
                      label: const Text('Post request'),
                    ),
                  ),
                  if (_requestReminder() case final reminder?) ...[
                    const SizedBox(height: AppSizes.fieldGap),
                    reminder,
                  ],
                  const SizedBox(height: AppSizes.sectionGap),
                  StatGrid(
                    tiles: [
                      StatTile(
                        icon: Icons.storefront_outlined,
                        value: _moreForSale
                            ? '${_newest.length}+'
                            : '${_newest.length}',
                        label: 'Crops for sale now',
                        highlight: true,
                        onTap: () => _open(HomeTab.market),
                      ),
                      StatTile(
                        icon: Icons.assignment_outlined,
                        value: '${_openRequests.length}',
                        label: 'Your open requests',
                        onTap: () => _open(HomeTab.requests),
                      ),
                      StatTile(
                        icon: Icons.favorite_border,
                        value: '$_following',
                        label: 'Crops and farmers you follow',
                        onTap: () => _open(HomeTab.following),
                      ),
                      // Opens Prices (on phones Prices is not in the
                      // bottom bar, so this tile is the way there).
                      StatTile(
                        icon: Icons.trending_up,
                        value: _newestMonth == null
                            ? '–'
                            : formatMonthKey(_newestMonth!),
                        label: 'PSA prices to compare',
                        onTap: () => _open(HomeTab.prices),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  _buildFreshCrops(),
                  const SizedBox(height: 14),
                  _buildBottomRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The newest crops for sale as cards: 2 to 4 per row.
  Widget _buildFreshCrops() {
    return SectionCard(
      icon: Icons.storefront_outlined,
      title: 'Fresh crops for sale',
      action: TextButton(
        onPressed: () => _open(HomeTab.market),
        child: const Text('Open Market'),
      ),
      child: _newest.isEmpty
          ? const Text('No crops for sale yet.', style: AppTextStyles.lead)
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 200).floor().clamp(
                  2,
                  4,
                );
                final shown = _newest.take(columns * 2).toList();
                const gap = 10.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final listing in shown)
                      SizedBox(
                        width: width,
                        height: width * 10 / 16 + 112,
                        child: ListingGridCard(
                          listing: listing,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ListingDetailScreen(listing: listing),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  /// "Your requests" and prices side by side on a wide screen.
  Widget _buildBottomRow() {
    final requests = SectionCard(
      icon: Icons.assignment_outlined,
      title: 'Your requests',
      action: TextButton(
        onPressed: () => _open(HomeTab.requests),
        child: const Text('See all'),
      ),
      child: _openRequests.isEmpty
          ? Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tell farmers what you need and they can message you.',
                    style: AppTextStyles.lead,
                  ),
                ),
                OutlinedButton(
                  onPressed: _postRequest,
                  child: const Text('Post request'),
                ),
              ],
            )
          : Column(
              children: [
                for (final request in _openRequests.take(3))
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
    final prices = SectionCard(
      icon: Icons.trending_up,
      title: 'PSA farmgate prices',
      action: TextButton(
        onPressed: () => _open(HomeTab.prices),
        child: const Text('All prices'),
      ),
      padChild: false,
      child: PriceMiniList(crops: kCrops.take(5).toList(), records: _prices),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [requests, const SizedBox(height: 14), prices],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: requests),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: prices),
          ],
        );
      },
    );
  }
}
