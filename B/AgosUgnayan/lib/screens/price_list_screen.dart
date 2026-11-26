// F6 Reference Prices: the latest monthly price of every crop, with the
// change from the month before. Works offline using the saved copy.
// The admin also gets "Get latest PSA prices" (downloads real prices from
// PSA OpenSTAT) and "Add price" (type one price by hand) here.

import 'package:flutter/material.dart';

import '../models/price_record.dart';
import '../services/auth_service.dart';
import '../services/price_service.dart';
import '../services/psa_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/paging.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import '../widgets/chip_filter_row.dart';
import '../widgets/crop_thumb.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/listing_card.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/price_change.dart';
import 'admin_price_form_screen.dart';
import 'price_detail_screen.dart';

enum _Sort { name, priceHigh, priceLow, change }

/// Prices tab for farmers, buyers and the admin.
class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  PriceData? _data;
  bool _isLoading = true;
  bool _isImporting = false;
  String? _error;
  String _search = '';
  CropCategory? _category; // null = all categories
  int _page = 1;
  final _scroll = ScrollController();
  _Sort _sort = _Sort.name;

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
      final data = await PriceService().fetchRecent();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openAdminForm() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminPriceFormScreen()),
    );
    if (saved == true) _load();
  }

  /// Downloads the last 24 months of PSA farmgate prices and saves them.
  /// Saving the same crop and month again only updates it.
  Future<void> _importFromPsa() async {
    setState(() => _isImporting = true);
    try {
      final result = await PsaService().fetchFarmgate();
      if (result.records.isEmpty) {
        throw const AppException('PSA has no new prices for our crops yet.');
      }
      await PriceService().saveMany(
        result.records,
        AuthService.currentUser!.id,
      );
      if (!mounted) return;
      final newest = result.records
          .map((record) => record.month)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final missing = result.missingCrops.isEmpty
          ? ''
          : ' No PSA price for ${result.missingCrops.join(', ')}.';
      showMessage(
        context,
        'Saved ${result.records.length} PSA prices '
        '(newest: ${formatMonthKey(newest)}).$missing',
      );
      _load();
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _isImporting = false);
  }

  /// The admin's two buttons under the page heading.
  Widget _buildAdminActions() {
    return Wrap(
      spacing: AppSizes.small,
      runSpacing: AppSizes.small,
      children: [
        FilledButton.icon(
          onPressed: _isImporting ? null : _importFromPsa,
          icon: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_download_outlined),
          label: Text(
            _isImporting ? 'Getting PSA prices…' : 'Get latest PSA prices',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isImporting ? null : _loadReferencePrices,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Load reference prices'),
        ),
        OutlinedButton.icon(
          onPressed: _isImporting ? null : _openAdminForm,
          icon: const Icon(Icons.add),
          label: const Text('Add price'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
  }

  /// Loads the crop catalog's PSA reference prices into the database
  /// (admin only), so everyone sees them even without the catalog.
  Future<void> _loadReferencePrices() async {
    setState(() => _isImporting = true);
    try {
      final added = await PriceService().saveReferencePrices(
        AuthService.currentUser!.id,
      );
      if (!mounted) return;
      showMessage(
        context,
        added == 0
            ? 'All reference prices are already saved.'
            : 'Saved $added reference prices, each with its own month. '
                  'Crops and months that already had a PSA price were kept.',
      );
      _load();
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _isImporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final records = _data?.records ?? [];
    // Only crops that have at least one price, matching the search.
    final crops = kCropCatalog
        .where((crop) => _category == null || crop.category == _category)
        .where(
          (crop) => matchesSearch(_search, [crop.name, ...crop.localNames]),
        )
        .map((crop) => crop.name)
        .where((crop) => PriceService.latestFor(crop, records) != null)
        .toList();
    double latest(String crop) => PriceService.latestFor(crop, records)!.price;
    switch (_sort) {
      case _Sort.name:
        crops.sort();
      case _Sort.priceHigh:
        crops.sort((a, b) => latest(b).compareTo(latest(a)));
      case _Sort.priceLow:
        crops.sort((a, b) => latest(a).compareTo(latest(b)));
      case _Sort.change:
        // Biggest change first, up or down.
        crops.sort(
          (a, b) => (PriceService.monthlyChange(b, records) ?? 0)
              .abs()
              .compareTo((PriceService.monthlyChange(a, records) ?? 0).abs()),
        );
    }
    final isAdmin = AuthService.currentUser?.isAdmin ?? false;
    final isBuyer = AuthService.currentUser?.isBuyer ?? false;
    final slice = pageOf(crops, _page, pageSize: 20);

    return ListPage(
      controller: _scroll,
      onRefresh: _load,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'Farmgate prices',
            title: 'Market prices',
            // Buyers use this to judge farmers' asking prices.
            lead: isBuyer
                ? "Compare these with farmers' asking prices before you "
                      'decide how much to offer.'
                : null,
            help: const [
              'These are PSA farmgate prices for Iloilo Province: what farmers '
                  'were paid per kg, on average, that month.',
              'The month is shown on every price. PSA publishes a few months '
                  'late, so these are a guide, not live prices.',
              '▲ means the price went up since the month before, ▼ down.',
              '"Older price" means PSA has no newer price for that crop yet; '
                  'its real month is shown.',
              'Tap a crop to see its last 12 months.',
            ],
          ),
          if (isAdmin) ...[const SizedBox(height: 12), _buildAdminActions()],
        ],
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_data?.savedCopyFrom != null) ...[
            _buildOfflineNote(),
            const SizedBox(height: 10),
          ],
          ListToolbar(
            search: SearchBox(
              hint: 'Search a crop…',
              onChanged: (text) => _update(() => _search = text),
            ),
            sort: SortMenu<_Sort>(
              value: _sort,
              options: const {
                _Sort.name: 'Crop name (A-Z)',
                _Sort.priceHigh: 'Highest price',
                _Sort.priceLow: 'Lowest price',
                _Sort.change: 'Biggest change',
              },
              onChanged: (sort) => _update(() => _sort = sort),
            ),
            resultText: _isLoading
                ? null
                : '${crops.length} crop${crops.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 10),
          CategoryChipRow(
            selected: _category,
            onSelected: (category) => _update(() => _category = category),
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: crops.isEmpty,
      emptyMessage: _search.isNotEmpty
          ? 'No crop matches "$_search".'
          : isAdmin
          ? 'No prices yet. Tap "Get latest PSA prices" to download them.'
          : 'No reference prices yet. Please check again later.',
      // 71 crops: 20 per page, two columns of rows on a wide screen.
      sliverBuilder: (context, width) => sliverCardGrid(
        contentWidth: width,
        count: slice.items.length,
        minTileWidth: 440,
        maxColumns: 2,
        tileHeight: 80,
        itemBuilder: (context, index) => Card(
          clipBehavior: Clip.antiAlias,
          child: _buildRow(slice.items[index], records),
        ),
      ),
      pagination: PaginationBar(
        slice: slice,
        onPage: (page) {
          setState(() => _page = page);
          if (_scroll.hasClients) _scroll.jumpTo(0);
        },
      ),
    );
  }

  /// Shown when there was no internet and we use the saved copy.
  Widget _buildOfflineNote() {
    return Row(
      children: [
        Expanded(
          child: NoticeBox(
            kind: NoticeKind.warning,
            message:
                'Offline: showing prices saved on '
                '${formatDate(_data!.savedCopyFrom!)}.',
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    );
  }

  Widget _buildRow(String crop, List<PriceRecord> records) {
    final history = PriceService.historyFor(crop, records);
    final latest = history.last;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PriceDetailScreen(
            crop: crop,
            history: history,
            isOlder: PriceService.isOlderPrice(crop, records),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CropThumb(crop: crop),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crop,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$kPriceSource · ${formatMonthKey(latest.month)}',
                    style: AppTextStyles.meta,
                    // One line, so the row keeps its height on a phone.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PriceText(price: latest.price, unit: 'kg'),
                const SizedBox(height: 2),
                PriceChangeText(
                  change: PriceService.monthlyChange(crop, records),
                  isOlder: PriceService.isOlderPrice(crop, records),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
