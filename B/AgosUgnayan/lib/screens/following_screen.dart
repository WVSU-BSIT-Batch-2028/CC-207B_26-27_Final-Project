// Following tab (replaces the old Follow and Saved features): the buyer
// switches between the crop listings and the farmers they follow.

import 'package:flutter/material.dart';

import '../models/followed_item.dart';
import '../services/auth_service.dart';
import '../services/following_service.dart';
import '../services/listing_service.dart';
import '../utils/app_exception.dart';
import '../utils/paging.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import '../widgets/crop_thumb.dart';
import '../widgets/page_header.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import 'farmer_profile_screen.dart';
import 'listing_detail_screen.dart';

/// Followed crop listings or farmers, picked with a segmented button.
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final _service = FollowingService();
  final _userId = AuthService.currentUser!.id;
  final _scroll = ScrollController();
  String _type = FollowType.listing; // which tab is selected
  List<FollowedItem> _listings = []; // followed crops
  List<FollowedItem> _farmers = []; // followed farmers
  bool _isLoading = true;
  String? _error;
  String _search = '';
  int _page = 1;

  /// The followed items of the selected tab.
  List<FollowedItem> get _items =>
      _type == FollowType.listing ? _listings : _farmers;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
      final results = await Future.wait([
        _service.fetch(_userId, FollowType.listing),
        _service.fetch(_userId, FollowType.farmer),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = results[0];
        _farmers = results[1];
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Opens the listing or the farmer, then reloads in case they unfollowed.
  Future<void> _open(FollowedItem item) async {
    Widget? page;
    if (item.type == FollowType.farmer) {
      page = FarmerProfileScreen(farmerId: item.targetId);
    } else {
      try {
        final listing = await ListingService().fetchById(item.targetId);
        if (listing != null) page = ListingDetailScreen(listing: listing);
      } catch (e) {
        if (mounted) showError(context, friendlyMessage(e));
        return;
      }
    }
    if (!mounted) return;
    if (page == null) {
      // The farmer deleted or sold this crop.
      showMessage(context, 'This crop is no longer for sale. We removed it.');
      await _unfollow(item, quiet: true);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
    _load();
  }

  Future<void> _unfollow(FollowedItem item, {bool quiet = false}) async {
    try {
      await _service.unfollow(_userId, item.targetId);
      if (!mounted) return;
      setState(() => _items.remove(item));
      if (quiet) return;
      // Undo follows it again with the same title and details.
      showUndoMessage(
        context,
        'Removed from Following.',
        onUndo: () async {
          await _service.follow(
            userId: _userId,
            targetId: item.targetId,
            type: item.type,
            title: item.title,
            subtitle: item.subtitle,
          );
          _load();
        },
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListings = _type == FollowType.listing;
    final visible = _items
        .where((item) => matchesSearch(_search, [item.title, item.subtitle]))
        .toList();
    final slice = pageOf(visible, _page, pageSize: 10);
    return ListPage(
      controller: _scroll,
      onRefresh: _load,
      header: const PageHeader(
        eyebrow: 'Saved for later',
        title: 'Following',
        help: [
          'Tap Follow on a crop or a farmer to keep them here.',
          'Tap the heart to unfollow; Undo brings it back.',
        ],
        lead: 'Crops and farmers you follow, to come back to them quickly.',
      ),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusTabs<String>(
            value: _type,
            labels: const {
              FollowType.listing: 'Crops',
              FollowType.farmer: 'Farmers',
            },
            counts: {
              FollowType.listing: _listings.length,
              FollowType.farmer: _farmers.length,
            },
            onChanged: (type) => setState(() {
              _type = type;
              _page = 1;
            }),
          ),
          const SizedBox(height: 10),
          ListToolbar(
            search: SearchBox(
              hint: isListings ? 'Search followed crops…' : 'Search farmers…',
              onChanged: (text) => setState(() {
                _search = text;
                _page = 1;
              }),
            ),
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: visible.isEmpty,
      emptyMessage: _search.isNotEmpty
          ? 'Nothing matches "$_search".'
          : isListings
          ? 'You are not following any crops yet.\n'
                'Open a crop in the Market and tap Follow.'
          : 'You are not following any farmers yet.\n'
                'Open a farmer\'s profile and tap Follow.',
      sliverBuilder: (context, width) => sliverCardGrid(
        contentWidth: width,
        count: slice.items.length,
        minTileWidth: 420,
        maxColumns: 2,
        tileHeight: 72,
        itemBuilder: (context, index) => _card(slice.items[index]),
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

  Widget _card(FollowedItem item) {
    final isListing = item.type == FollowType.listing;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _open(item),
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        leading: isListing
            // The title starts with the crop name, e.g. "Tomato · 50 kg".
            ? CropThumb(crop: item.title.split(' · ').first)
            : CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  item.title.isEmpty ? '?' : item.title[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.cardTitle,
        ),
        subtitle: Text(
          item.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.meta,
        ),
        trailing: IconButton(
          tooltip: 'Unfollow',
          icon: const Icon(Icons.favorite, color: AppColors.danger),
          onPressed: () => _unfollow(item),
        ),
      ),
    );
  }
}
