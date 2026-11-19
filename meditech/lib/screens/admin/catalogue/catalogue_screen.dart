import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/catalogue_medicine.dart';
import '../../../providers/catalogue_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'medicine_drawer.dart';

// Catalogue statuses as the admin sees them. 'draft' entries are waiting for an
// FDA check and approval, so they read as "Pending review".
const medicineStatuses = <String, (String, BadgeTone)>{
  'draft': ('Pending review', BadgeTone.warning),
  'active': ('Active', BadgeTone.success),
  'inactive': ('Inactive', BadgeTone.danger),
};

// Badge for a catalogue entry's status
StatusBadge medicineStatusBadge(String status) {
  final (label, tone) = medicineStatuses[status] ?? ('Inactive', BadgeTone.danger);
  return StatusBadge(label, tone: tone);
}

// Plain-language drug classification
String medicineClassification(bool isRx) =>
    isRx ? 'Prescription Drug (Rx)' : 'Over-the-Counter (OTC) Drug';

// Admin medicine catalogue (wireframes A-12, A-14, A-15)
class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  // Below this width the drawer replaces the page instead of sitting beside it
  static const _sideBySideMinWidth = 1500.0;

  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Search as the admin types, after a short pause
  void _onSearchChanged(String text) {
    setState(() {}); // show or hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250),
        () => ref.read(catalogueFilterProvider.notifier).setSearch(text));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(catalogueFilterProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catalogueFilterProvider);
    final selected = ref.watch(selectedMedicineProvider);
    final rows = ref.watch(catalogueListProvider);
    final select = ref.read(selectedMedicineProvider.notifier).select;
    final view = rows.whenData((all) => CatalogueView.of(all, filter));

    final drawer = selected == null
        ? null
        : MedicineDrawer(
            key: ValueKey(selected),
            medicine: selected == 'new'
                ? null
                : rows.value?.where((m) => m.id == selected).firstOrNull,
            onClose: () => select(null),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine catalogue'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: FilledButton.icon(
              onPressed: () => select('new'),
              icon: const Icon(Icons.add),
              label: const Text('Add medicine'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        // Too narrow for the table and a 460px drawer side by side
        if (drawer != null && constraints.maxWidth < _sideBySideMinWidth) {
          return Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: drawer);
        }

        final page = SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _StatCards(all: rows.value, status: filter.status),
            const SizedBox(height: AppSpacing.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _Toolbar(
                    search: _search,
                    onSearchChanged: _onSearchChanged,
                    onClearSearch: _clearSearch,
                    filter: filter,
                    counts: view.value?.statusCounts,
                  ),
                ),
                const Divider(),
                AsyncView<CatalogueView>(
                  value: view,
                  onRetry: () => ref.invalidate(catalogueListProvider),
                  isEmpty: (v) => v.matching == 0,
                  emptyMessage: 'No medicines match these filters.',
                  builder: (v) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: _ListBar(view: v, filter: filter),
                    ),
                    _Table(
                      rows: v.rows,
                      selectedId: selected,
                      filter: filter,
                      onOpen: select,
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        );

        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: page),
          if (drawer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              child: SizedBox(width: 460, child: drawer),
            ),
        ]);
      }),
    );
  }
}

// Totals across the whole catalogue; tapping one filters the table
class _StatCards extends ConsumerWidget {
  const _StatCards({required this.all, required this.status});

  final List<CatalogueMedicine>? all; // null while loading
  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int? count(String? s) => all?.where((m) => s == null || m.status == s).length;
    final setStatus = ref.read(catalogueFilterProvider.notifier).setStatus;

    final cards = [
      _StatCard(
        icon: Icons.medication_outlined,
        label: 'Total medicines',
        value: count(null),
        color: AppColors.primary,
        background: AppColors.primaryLight,
        selected: status == null,
        onTap: () => setStatus(null),
      ),
      _StatCard(
        icon: Icons.check_circle_outline,
        label: 'Active',
        value: count('active'),
        color: AppColors.primary,
        background: AppColors.primaryLight,
        selected: status == 'active',
        onTap: () => setStatus('active'),
      ),
      _StatCard(
        icon: Icons.pending_actions_outlined,
        label: 'Pending review',
        value: count('draft'),
        color: AppColors.warning,
        background: AppColors.warningLight,
        selected: status == 'draft',
        onTap: () => setStatus('draft'),
      ),
      _StatCard(
        icon: Icons.block,
        label: 'Inactive',
        value: count('inactive'),
        color: AppColors.danger,
        background: AppColors.dangerLight,
        selected: status == 'inactive',
        onTap: () => setStatus('inactive'),
      ),
    ];

    // Four across on wide screens, two by two otherwise
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth >= 860 ? 4 : 2;
      final width = (constraints.maxWidth - AppSpacing.md * (perRow - 1)) / perRow;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [for (final c in cards) SizedBox(width: width, child: c)],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int? value;
  final Color color;
  final Color background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                Text(value?.toString() ?? '–',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// Search, status tabs with counts, and the "More filters" menu
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.search,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.filter,
    required this.counts,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final CatalogueFilter filter;
  final Map<String?, int>? counts; // null while loading

  static const _tabs = <(String, String?)>[
    ('All', null),
    ('Pending review', 'draft'),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogueFilterProvider.notifier);

    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.lg,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        // Search
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const _FieldLabel('Search medicines'),
            TextField(
              controller: search,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Brand, generic name, or registration number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: onClearSearch),
              ),
            ),
          ]),
        ),

        // Status tabs
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const _FieldLabel('Filter by status'),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final (label, value) in _tabs)
              ChoiceChip(
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: filter.status == value ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
                label: Text(counts == null ? label : '$label (${counts![value] ?? 0})'),
                selected: filter.status == value,
                onSelected: (_) => notifier.setStatus(value),
              ),
          ]),
        ]),

        _MoreFilters(filter: filter),
      ],
    );
  }
}

// Classification and FDA check filters
class _MoreFilters extends ConsumerWidget {
  const _MoreFilters({required this.filter});

  final CatalogueFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogueFilterProvider.notifier);
    final active = filter.extraFilterCount;

    PopupMenuEntry<String> heading(String text) => PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        );
    PopupMenuEntry<String> option(String value, String label, bool checked) =>
        CheckedPopupMenuItem<String>(value: value, checked: checked, child: Text(label));

    return PopupMenuButton<String>(
      tooltip: 'More filters',
      position: PopupMenuPosition.under,
      onSelected: (v) => switch (v) {
        'rx:any' => notifier.setRx(null),
        'rx:yes' => notifier.setRx(true),
        'rx:no' => notifier.setRx(false),
        'fda:any' => notifier.setFdaMatched(null),
        'fda:yes' => notifier.setFdaMatched(true),
        'fda:no' => notifier.setFdaMatched(false),
        _ => notifier.clearExtraFilters(),
      },
      itemBuilder: (_) => [
        heading('CLASSIFICATION'),
        option('rx:any', 'Any classification', filter.isRx == null),
        option('rx:yes', 'Prescription Drug (Rx)', filter.isRx == true),
        option('rx:no', 'Over-the-Counter (OTC) Drug', filter.isRx == false),
        const PopupMenuDivider(),
        heading('FDA CHECK'),
        option('fda:any', 'Any result', filter.fdaMatched == null),
        option('fda:yes', 'Matched and valid', filter.fdaMatched == true),
        option('fda:no', 'Not matched yet', filter.fdaMatched == false),
        if (active > 0) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'clear', child: Text('Clear filters')),
        ],
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: active > 0 ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(color: active > 0 ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(active > 0 ? 'More filters ($active)' : 'More filters',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
          const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

// "Showing 1–10 of 128", sort, items per page, and page numbers
class _ListBar extends ConsumerWidget {
  const _ListBar({required this.view, required this.filter});

  final CatalogueView view;
  final CatalogueFilter filter;

  static const _sortLabels = {
    CatalogueSort.generic: 'Generic name',
    CatalogueSort.brand: 'Brand name',
    CatalogueSort.registration: 'Registration no.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogueFilterProvider.notifier);
    const muted = TextStyle(color: AppColors.textMuted);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        Text('Showing ${view.firstShown}–${view.lastShown} of ${view.matching} '
            '${view.matching == 1 ? 'medicine' : 'medicines'}', style: muted),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Sort by: ', style: muted),
              _Select<CatalogueSort>(
                value: filter.sort,
                items: {for (final e in _sortLabels.entries) e.key: e.value},
                onChanged: (s) => notifier.setSort(s, ascending: filter.ascending),
              ),
              IconButton(
                tooltip: filter.ascending ? 'A to Z' : 'Z to A',
                visualDensity: VisualDensity.compact,
                onPressed: () => notifier.toggleSort(filter.sort),
                icon: Icon(filter.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
              ),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Items per page: ', style: muted),
              _Select<int>(
                value: filter.perPage,
                items: const {10: '10', 25: '25', 50: '50'},
                onChanged: notifier.setPerPage,
              ),
            ]),
            _Pager(page: view.page, pageCount: view.pageCount, onPage: notifier.setPage),
          ],
        ),
      ],
    );
  }
}

// A small bordered drop-down
class _Select<T> extends StatelessWidget {
  const _Select({required this.value, required this.items, required this.onChanged});

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// Previous, page numbers (with gaps when there are many), next
class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pageCount, required this.onPage});

  final int page; // zero-based
  final int pageCount;
  final ValueChanged<int> onPage;

  // Pages to show, zero-based; null marks a gap
  List<int?> get _numbers {
    if (pageCount <= 7) return [for (var i = 0; i < pageCount; i++) i];
    final around = {0, page - 1, page, page + 1, pageCount - 1}.where((i) => i >= 0 && i < pageCount).toList()
      ..sort();
    final out = <int?>[];
    for (final i in around) {
      if (out.isNotEmpty && out.last != null && i - out.last! > 1) out.add(null);
      out.add(i);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    Widget box({required Widget child, VoidCallback? onTap, bool selected = false, String? tooltip}) {
      final tile = Material(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 34, height: 34, child: Center(child: child)),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: tooltip == null ? tile : Tooltip(message: tooltip, child: tile),
      );
    }

    final first = page == 0, last = page >= pageCount - 1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      box(
        tooltip: 'Previous page',
        onTap: first ? null : () => onPage(page - 1),
        child: Icon(Icons.chevron_left, size: 20, color: first ? AppColors.border : AppColors.text),
      ),
      for (final n in _numbers)
        n == null
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…', style: TextStyle(color: AppColors.textMuted)),
              )
            : box(
                selected: n == page,
                onTap: n == page ? null : () => onPage(n),
                child: Text('${n + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: n == page ? Colors.white : AppColors.text,
                    )),
              ),
      box(
        tooltip: 'Next page',
        onTap: last ? null : () => onPage(page + 1),
        child: Icon(Icons.chevron_right, size: 20, color: last ? AppColors.border : AppColors.text),
      ),
    ]);
  }
}

// The catalogue table: registration, generic, brand, strength and form,
// classification, status, and actions
class _Table extends ConsumerWidget {
  const _Table({required this.rows, required this.selectedId, required this.filter, required this.onOpen});

  final List<CatalogueMedicine> rows;
  final String? selectedId;
  final CatalogueFilter filter;
  final void Function(String id) onOpen;

  static const _sortColumns = [CatalogueSort.registration, CatalogueSort.generic, CatalogueSort.brand];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogueFilterProvider.notifier);

    // A text cell capped in width that wraps to at most two lines
    DataCell cell(String text, double maxWidth, {TextStyle? style}) => DataCell(ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
        ));

    DataColumn sortable(String label, CatalogueSort sort) =>
        DataColumn(label: Text(label), onSort: (_, _) => notifier.toggleSort(sort));

    Future<void> copy(String number) async {
      await Clipboard.setData(ClipboardData(text: number));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Registration number copied.')));
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Scroll sideways instead of squeezing cells when it doesn't fit
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: AppSpacing.xl,
            horizontalMargin: AppSpacing.lg,
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 68,
            headingRowColor: const WidgetStatePropertyAll(AppColors.background),
            headingTextStyle:
                const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 13),
            sortColumnIndex: _sortColumns.indexOf(filter.sort),
            sortAscending: filter.ascending,
            columns: [
              sortable('Registration No.', CatalogueSort.registration),
              sortable('Generic Name', CatalogueSort.generic),
              sortable('Brand Name', CatalogueSort.brand),
              const DataColumn(label: Text('Dosage Strength and Form')),
              const DataColumn(label: Text('Classification')),
              const DataColumn(label: Text('Status')),
              const DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final m in rows)
                DataRow(
                  selected: m.id == selectedId,
                  onSelectChanged: (_) => onOpen(m.id),
                  cells: [
                    m.registrationNumber == null
                        ? const DataCell(Text('—', style: TextStyle(color: AppColors.textMuted)))
                        : cell(m.registrationNumber!, 150),
                    cell(m.genericName, 220),
                    cell(m.brandName, 180, style: const TextStyle(fontWeight: FontWeight.w700)),
                    cell('${m.strength} ${m.dosageForm}', 220),
                    cell(medicineClassification(m.isRx), 170),
                    DataCell(medicineStatusBadge(m.status)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton(
                        onPressed: () => onOpen(m.id),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('View details'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More actions',
                        icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                        onSelected: (v) => v == 'copy' ? copy(m.registrationNumber!) : onOpen(m.id),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'open', child: Text('Open details')),
                          if (m.registrationNumber != null)
                            const PopupMenuItem(value: 'copy', child: Text('Copy registration number')),
                        ],
                      ),
                    ])),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }
}

// A small bold label above a control
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
      );
}
