import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/osm_listing.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Admin screen for managing OpenStreetMap "Not on MediTech" pharmacy listings
class OsmListingsScreen extends ConsumerStatefulWidget {
  const OsmListingsScreen({super.key, this.showHeader = true});

  final bool showHeader;

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AsyncView<List<OsmListing>>(
        value: asyncListings,
        onRetry: () => ref.invalidate(adminOsmListingsProvider),
        builder: (listings) {
          final filtered = _filtered(listings);

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                        icon: _syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(
                          _syncing ? 'Syncing...' : 'Sync from OpenStreetMap',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Search bar + status filter chips
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search name, barangay, or OSM ID',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: AppColors.surface,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),
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

                // Listings table card
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No OpenStreetMap listings match the current filter.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 76,
                                columnSpacing: 12,
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.background,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Pharmacy name')),
                                  DataColumn(label: Text('Address')),
                                  DataColumn(label: Text('Last edited there')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Action')),
                                ],
                                rows: filtered.map((listing) {
                                  final isBusy = _busyId == listing.id;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              listing.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              listing.osmId,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(listing.address)),
                                      DataCell(
                                        Text(listing.lastEditedThere ?? '—'),
                                      ),
                                      DataCell(
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _statusBadge(listing),
                                            if (listing.status ==
                                                    OsmListingStatus.replaced &&
                                                listing.replacedByPharmacyName !=
                                                    null)
                                              Text(
                                                'Replaced by ${listing.replacedByPharmacyName}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            if (listing.status ==
                                                    OsmListingStatus.hidden &&
                                                listing.hiddenReason != null)
                                              Text(
                                                listing.hiddenReason!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      DataCell(switch (listing.status) {
                                        OsmListingStatus.shown =>
                                          OutlinedButton(
                                            onPressed: isBusy
                                                ? null
                                                : () => _onHide(listing),
                                            child: const Text('Hide'),
                                          ),
                                        OsmListingStatus.hidden =>
                                          OutlinedButton(
                                            onPressed: isBusy
                                                ? null
                                                : () => _onShowAgain(listing),
                                            child: const Text('Show again'),
                                          ),
                                        OsmListingStatus.replaced => const Text(
                                          '—',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      }),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
