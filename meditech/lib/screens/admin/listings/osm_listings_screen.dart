import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/osm_listing.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Admin screen for managing OpenStreetMap "Not on MediTech" pharmacy listings
class OsmListingsScreen extends ConsumerStatefulWidget {
  const OsmListingsScreen({
    super.key,
    this.showHeader = true,
    this.embedded = false,
  });

  final bool showHeader;

  /// Inside [PharmaciesScreen] — no [Scaffold], no extra padding.
  final bool embedded;

  @override
  ConsumerState<OsmListingsScreen> createState() => _OsmListingsScreenState();
}

class _OsmListingsScreenState extends ConsumerState<OsmListingsScreen> {
  final _search = TextEditingController();
  String _statusFilter = 'all';
  bool _syncing = false;
  String? _busyId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  StatusBadge _statusBadge(OsmListing listing) => switch (listing.status) {
    OsmListingStatus.shown => const StatusBadge(
      'Shown',
      tone: BadgeTone.success,
    ),
    OsmListingStatus.replaced => const StatusBadge(
      'Replaced',
      tone: BadgeTone.info,
    ),
    OsmListingStatus.hidden => const StatusBadge(
      'Hidden',
      tone: BadgeTone.neutral,
    ),
  };

  List<OsmListing> _filtered(List<OsmListing> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((item) {
      final statusMatches = switch (_statusFilter) {
        'shown' => item.status == OsmListingStatus.shown,
        'replaced' => item.status == OsmListingStatus.replaced,
        'hidden' => item.status == OsmListingStatus.hidden,
        _ => true,
      };
      if (!statusMatches) return false;
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          item.address.toLowerCase().contains(q) ||
          item.osmId.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _onSync() async {
    setState(() => _syncing = true);
    try {
      final count = await ref
          .read(adminOsmListingsProvider.notifier)
          .syncFromOpenStreetMap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced $count OpenStreetMap listings for Iloilo.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _onHide(OsmListing listing) async {
    final reason = await showReasonDialog(
      context,
      title: 'Hide "${listing.name}"?',
      description: 'Patients will no longer see this OpenStreetMap listing. Tell other admins why it is being hidden.',
      actionLabel: 'Hide listing',
      hint: 'e.g., Duplicate pin or wrong barangay',
    );
    if (reason == null || !mounted) return;

    setState(() => _busyId = listing.id);
    try {
      await ref
          .read(adminOsmListingsProvider.notifier)
          .hideListing(listingId: listing.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${listing.name} is now hidden from patients.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not hide listing: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _onShowAgain(OsmListing listing) async {
    setState(() => _busyId = listing.id);
    try {
      await ref
          .read(adminOsmListingsProvider.notifier)
          .showListingAgain(listingId: listing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${listing.name} is shown to patients again.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not restore listing: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncListings = ref.watch(adminOsmListingsProvider);

    final body = AsyncView<List<OsmListing>>(
      value: asyncListings,
      onRetry: () => ref.invalidate(adminOsmListingsProvider),
      builder: (listings) {
        final filtered = _filtered(listings);

        return Padding(
          padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHeader) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not on MediTech listings',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pharmacies pulled from OpenStreetMap for Iloilo. Replaced automatically when a pharmacy registers and is approved.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _syncing ? null : _onSync,
                        style: TabletControls.toolbarOutlined(),
                        icon: _syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(_syncing ? 'Syncing…' : 'Sync OSM'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: TabletControls.toolbarHeight,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: TabletControls.searchDecoration(
                          hint: 'Name, address, or OSM ID',
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _search.clear()),
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.embedded) ...[
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _syncing ? null : _onSync,
                      style: TabletControls.toolbarOutlined(),
                      icon: _syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(_syncing ? 'Syncing…' : 'Sync OSM'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChip(
                      label: 'All (${listings.length})',
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                    AppChip(
                      label: 'Shown',
                      selected: _statusFilter == 'shown',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'shown'),
                    ),
                    AppChip(
                      label: 'Replaced',
                      selected: _statusFilter == 'replaced',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'replaced'),
                    ),
                    AppChip(
                      label: 'Hidden',
                      selected: _statusFilter == 'hidden',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'hidden'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const _OsmTableHeader(),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No OpenStreetMap listings match the current filter.',
                                    style: TextStyle(color: AppColors.textMuted),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, index) => _OsmListingRow(
                                    listing: filtered[index],
                                    statusBadge: _statusBadge(filtered[index]),
                                    busy: _busyId == filtered[index].id,
                                    onHide: () => _onHide(filtered[index]),
                                    onShowAgain: () => _onShowAgain(filtered[index]),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
    );

    if (widget.embedded) return body;

    return Scaffold(backgroundColor: AppColors.background, body: body);
  }
}

class _OsmTableHeader extends StatelessWidget {
  const _OsmTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('PHARMACY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 4, child: Text('ADDRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 2, child: Text('LAST EDITED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 3, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 2, child: Text('ACTION', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }
}

class _OsmListingRow extends StatelessWidget {
  const _OsmListingRow({
    required this.listing,
    required this.statusBadge,
    required this.busy,
    required this.onHide,
    required this.onShowAgain,
  });

  final OsmListing listing;
  final StatusBadge statusBadge;
  final bool busy;
  final VoidCallback onHide;
  final VoidCallback onShowAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  listing.osmId,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              listing.address,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(listing.lastEditedThere ?? '—', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusBadge,
                if (listing.status == OsmListingStatus.replaced &&
                    listing.replacedByPharmacyName != null)
                  Text(
                    'Replaced by ${listing.replacedByPharmacyName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (listing.status == OsmListingStatus.hidden && listing.hiddenReason != null)
                  Text(
                    listing.hiddenReason!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: switch (listing.status) {
                OsmListingStatus.shown => OutlinedButton(
                    onPressed: busy ? null : onHide,
                    style: TabletControls.toolbarOutlined(),
                    child: const Text('Hide'),
                  ),
                OsmListingStatus.hidden => OutlinedButton(
                    onPressed: busy ? null : onShowAgain,
                    style: TabletControls.toolbarOutlined(),
                    child: const Text('Show again'),
                  ),
                OsmListingStatus.replaced => const Text('—', style: TextStyle(color: AppColors.textMuted)),
              },
            ),
          ),
        ],
      ),
    );
  }
}
