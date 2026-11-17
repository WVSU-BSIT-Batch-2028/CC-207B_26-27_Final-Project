import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/pharmacy_summary.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'application_drawer.dart';

// Badge for a pharmacy's status
StatusBadge branchStatusBadge(String status) => switch (status) {
      'pending_approval' => const StatusBadge('Pending', tone: BadgeTone.warning),
      'active' => const StatusBadge('Active', tone: BadgeTone.success),
      'rejected' => const StatusBadge('Rejected', tone: BadgeTone.danger),
      _ => const StatusBadge('Inactive'),
    };

// Admin pharmacies list with the application drawer (wireframes A-03, A-04)
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  static const _tabs = <(String, String?)>[
    ('All', null),
    ('Pending', 'pending_approval'),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
    ('Rejected', 'rejected'),
  ];

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(pharmacyFilterProvider);
    final selected = ref.watch(selectedPharmacyProvider);
    final rows = ref.watch(pharmacyListProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacies')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            SizedBox(
              width: 360,
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => ref.read(pharmacyFilterProvider.notifier).setSearch(v),
                decoration: InputDecoration(
                  hintText: 'Search pharmacy, owner, LTO, or PHM number',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            ref.read(pharmacyFilterProvider.notifier).setSearch('');
                            setState(() {});
                          },
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Status tabs
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (label, value) in _tabs)
                  ChoiceChip(
                    label: Text(label),
                    selected: filter.status == value,
                    onSelected: (_) => ref.read(pharmacyFilterProvider.notifier).setStatus(value),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // The table, with the drawer beside it on wide screens
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: AsyncView<List<PharmacySummary>>(
                        value: rows,
                        onRetry: () => ref.invalidate(pharmacyListProvider),
                        isEmpty: (list) => list.isEmpty,
                        emptyMessage: 'No pharmacies match these filters.',
                        builder: (list) => _Table(
                          rows: list,
                          selectedId: selected,
                          compact: selected != null,
                          onOpen: (id) {
                            ref.read(selectedPharmacyProvider.notifier).select(id);
                            if (!wide) _openAsSheet(id);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (wide && selected != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 440,
                      child: ApplicationDrawer(
                        branchId: selected,
                        onClose: () => ref.read(selectedPharmacyProvider.notifier).select(null),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // On narrower screens, show the application full-height from the right
  Future<void> _openAsSheet(String id) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 440,
          child: ApplicationDrawer(branchId: id, onClose: () => Navigator.pop(context)),
        ),
      ),
    );
    ref.read(selectedPharmacyProvider.notifier).select(null);
  }
}

// The pharmacies table; fewer columns while the drawer is open
class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.selectedId, required this.compact, required this.onOpen});

  final List<PharmacySummary> rows;
  final String? selectedId;
  final bool compact;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy');
    final today = DateUtils.dateOnly(DateTime.now());

    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: [
            const DataColumn(label: Text('Pharmacy')),
            if (!compact) const DataColumn(label: Text('Owner')),
            const DataColumn(label: Text('LTO expiry')),
            if (!compact) const DataColumn(label: Text('Submitted')),
            const DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final p in rows)
              DataRow(
                selected: p.id == selectedId,
                onSelectChanged: (_) => onOpen(p.id),
                cells: [
                  // Name, branch, and a duplicate warning
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(p.pharmacyName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (p.possibleDuplicate) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Tooltip(
                            message: 'Possible duplicate',
                            child: Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                          ),
                        ],
                      ]),
                      Text('${p.branchName} · ${p.displayId}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  )),
                  if (!compact) DataCell(Text(p.ownerName ?? '-')),
                  // Expired licenses show in red
                  DataCell(Text(
                    date.format(p.ltoExpiry),
                    style: TextStyle(color: p.ltoExpiry.isBefore(today) ? AppColors.danger : null),
                  )),
                  if (!compact) DataCell(Text(date.format(p.submittedAt))),
                  DataCell(branchStatusBadge(p.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}