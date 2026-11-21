import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/pharmacy_summary.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'application_drawer.dart';

// Badge for a pharmacy's status (the drawer uses this too)
StatusBadge branchStatusBadge(String status) => switch (status) {
  'pending_approval' => const StatusBadge('Pending', tone: BadgeTone.warning),
  'active' => const StatusBadge('Active', tone: BadgeTone.success),
  'rejected' => const StatusBadge('Rejected', tone: BadgeTone.danger),
  _ => const StatusBadge('Inactive'),
};

// Columns the table can sort by
enum _SortBy { pharmacy, owner, ltoExpiry, submitted, status }

// Admin pharmacies list with the application drawer (wireframes A-03, A-04)
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key, this.showHeader = true, this.initialChip = 'all'});

  // Turn off when Emman's admin frame already shows a header
  final bool showHeader;

  // The chip selected on opening: 'all', a status, or 'lto_expiring'
  // (the overview cards open the matching view)
  final String initialChip;

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  static const _perPage = 10;
  static const _chips = <(String, String)>[
    ('All', 'all'),
    ('Pending', 'pending_approval'),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
    ('Rejected', 'rejected'),
    ('LTO expiring in 60 days', 'lto_expiring'),
  ];

  final _search = TextEditingController();
  late String _chip = widget.initialChip;
  _SortBy _sortBy = _SortBy.submitted;
  bool _ascending = false; // newest first
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Search, chip, and sort applied on the device
  List<PharmacySummary> _filtered(List<PharmacySummary> all) {
    final today = DateTime.now();
    final q = _search.text.trim().toLowerCase();

    final rows = all.where((p) {
      // Status chip
      final chipOk = switch (_chip) {
        'all' => true,
        'lto_expiring' => isLtoExpiringSoon(p, today), // same rule as the overview card
        _ => p.status == _chip,
      };
      if (!chipOk) return false;

      // Search by pharmacy, branch, owner, LTO, or PHM number
      if (q.isEmpty) return true;
      return [
        p.pharmacyName,
        p.branchName,
        p.ownerName ?? '',
        p.ltoNumber,
        p.displayId,
      ].any((field) => field.toLowerCase().contains(q));
    }).toList();

    // Sort by the chosen column
    int compare(PharmacySummary a, PharmacySummary b) => switch (_sortBy) {
      _SortBy.pharmacy => '${a.pharmacyName} ${a.branchName}'.compareTo('${b.pharmacyName} ${b.branchName}'),
      _SortBy.owner => (a.ownerName ?? '').compareTo(b.ownerName ?? ''),
      _SortBy.ltoExpiry => a.ltoExpiry.compareTo(b.ltoExpiry),
      _SortBy.submitted => a.submittedAt.compareTo(b.submittedAt),
      _SortBy.status => a.status.compareTo(b.status),
    };
    rows.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return rows;
  }

  // Tap a column title to sort; tap again to flip the order
  void _sort(_SortBy by) => setState(() {
    if (_sortBy == by) {
      _ascending = !_ascending;
    } else {
      _sortBy = by;
      _ascending = true;
    }
    _page = 0;
  });

  // Open an application: beside the table on wide screens, over it on narrow ones
  void _openRow(String id, bool wide) {
    ref.read(selectedPharmacyProvider.notifier).select(id);
    if (!wide) _openAsSheet(id);
  }

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

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(pharmacyListProvider);
    final selected = ref.watch(selectedPharmacyProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        child: _MinHeight(
          minHeight: 640,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and subtitle, with a back arrow when opened from another screen
                if (widget.showHeader) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canGoBack) ...[
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pharmacies', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              'Manage pharmacy branches and their information.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Search bar
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() => _page = 0),
                  decoration: InputDecoration(
                    hintText: 'Search pharmacy, owner, LTO, or PHM number…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _search.clear();
                              _page = 0;
                            }),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Status chips
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (label, value) in _chips)
                      ChoiceChip(
                        avatar: value == 'lto_expiring'
                            ? const Icon(Icons.event_busy_outlined, size: 16, color: AppColors.danger)
                            : null,
                        label: Text(label),
                        selected: _chip == value,
                        onSelected: (_) => setState(() {
                          _chip = value;
                          _page = 0;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // The list card, with the drawer beside it on wide screens
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: AsyncView<List<PharmacySummary>>(
                            value: rows,
                            onRetry: () => ref.invalidate(pharmacyListProvider),
                            builder: (all) {
                              final filtered = _filtered(all);
                              final pages = (filtered.length / _perPage).ceil().clamp(1, 9999);
                              final page = _page.clamp(0, pages - 1);
                              final shown = filtered.skip(page * _perPage).take(_perPage).toList();
                              final compact = (wide && selected != null) || MediaQuery.sizeOf(context).width < 760;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Card title
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      AppSpacing.lg,
                                      AppSpacing.lg,
                                      AppSpacing.md,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pharmacy list',
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          'View and manage all registered pharmacies.',
                                          style: TextStyle(color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Header row
                                  _HeaderRow(compact: compact, sortBy: _sortBy, ascending: _ascending, onSort: _sort),

                                  // Rows, or an empty message
                                  Expanded(
                                    child: shown.isEmpty
                                        ? const StateMessage(
                                            icon: Icons.storefront_outlined,
                                            message: 'No pharmacies match these filters.',
                                          )
                                        : ListView.separated(
                                            itemCount: shown.length,
                                            separatorBuilder: (_, _) => const Divider(height: 1),
                                            itemBuilder: (_, i) => _PharmacyRow(
                                              pharmacy: shown[i],
                                              compact: compact,
                                              selected: shown[i].id == selected,
                                              onView: () => _openRow(shown[i].id, wide),
                                            ),
                                          ),
                                  ),

                                  // Footer: count and pages
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            filtered.isEmpty
                                                ? 'No pharmacies'
                                                : 'Showing ${page * _perPage + 1}–${page * _perPage + shown.length} '
                                                      'of ${filtered.length} pharmacies',
                                            style: const TextStyle(color: AppColors.textMuted),
                                          ),
                                        ),
                                        // Page buttons scroll sideways when there are too many to fit
                                        Flexible(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _PageButton(
                                                  icon: Icons.chevron_left,
                                                  onTap: page > 0 ? () => setState(() => _page = page - 1) : null,
                                                ),
                                                for (var p = 0; p < pages; p++)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                                    child: p == page
                                                        ? FilledButton(
                                                            onPressed: () {},
                                                            style: FilledButton.styleFrom(
                                                              minimumSize: const Size(40, 40),
                                                              padding: EdgeInsets.zero,
                                                            ),
                                                            child: Text('${p + 1}'),
                                                          )
                                                        : OutlinedButton(
                                                            onPressed: () => setState(() => _page = p),
                                                            style: OutlinedButton.styleFrom(
                                                              minimumSize: const Size(40, 40),
                                                              padding: EdgeInsets.zero,
                                                              side: const BorderSide(color: AppColors.border),
                                                            ),
                                                            child: Text('${p + 1}'),
                                                          ),
                                                  ),
                                                _PageButton(
                                                  icon: Icons.chevron_right,
                                                  onTap: page < pages - 1
                                                      ? () => setState(() => _page = page + 1)
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
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
        ),
      ),
    );
  }
}

// On windows shorter than minHeight, keep the layout at minHeight and let the
// whole page scroll instead of squeezing the list card until it overflows
class _MinHeight extends StatelessWidget {
  const _MinHeight({required this.minHeight, required this.child});

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => box.maxHeight >= minHeight
          ? child
          : SingleChildScrollView(
              child: SizedBox(height: minHeight, child: child),
            ),
    );
  }
}

// Column widths shared by the header and the rows
const _flexPharmacy = 5;
const _flexOwner = 3;
const _flexLto = 3;
const _flexSubmitted = 3;
const _flexStatus = 3;
const _actionsWidth = 140.0; // View button plus the ⋮ menu

// Tinted header row with sortable column titles
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.compact, required this.sortBy, required this.ascending, required this.onSort});

  final bool compact;
  final _SortBy sortBy;
  final bool ascending;
  final void Function(_SortBy) onSort;

  // One sortable column title
  Widget _title(String text, _SortBy by, int flex) => Expanded(
    flex: flex,
    child: InkWell(
      onTap: () => onSort(by),
      child: Row(
        children: [
          Flexible(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          Icon(
            sortBy == by ? (ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
            size: 16,
            color: sortBy == by ? AppColors.primary : AppColors.textMuted,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          _title('Pharmacy', _SortBy.pharmacy, _flexPharmacy),
          if (!compact) _title('Owner', _SortBy.owner, _flexOwner),
          _title('LTO expiry', _SortBy.ltoExpiry, _flexLto),
          if (!compact) _title('Submitted', _SortBy.submitted, _flexSubmitted),
          _title('Status', _SortBy.status, _flexStatus),
          const SizedBox(
            width: _actionsWidth,
            child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// One pharmacy row: icon, name, owner, dates, status pill, View and ⋮
class _PharmacyRow extends StatelessWidget {
  const _PharmacyRow({required this.pharmacy, required this.compact, required this.selected, required this.onView});

  final PharmacySummary pharmacy;
  final bool compact;
  final bool selected;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final p = pharmacy;
    final date = DateFormat('MMM d, yyyy');
    final expired = p.ltoExpiry.isBefore(DateUtils.dateOnly(DateTime.now()));

    return Material(
      color: selected ? AppColors.primaryLight.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              // Icon, name, branch, and PHM number
              Expanded(
                flex: _flexPharmacy,
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.storefront, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.pharmacyName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                              if (p.possibleDuplicate) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Tooltip(
                                  message: 'Possible duplicate',
                                  child: Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${p.branchName} • ${p.displayId}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) Expanded(flex: _flexOwner, child: Text(p.ownerName ?? '–')),
              // Expired licenses show in red
              Expanded(
                flex: _flexLto,
                child: Text(date.format(p.ltoExpiry), style: TextStyle(color: expired ? AppColors.danger : null)),
              ),
              if (!compact) Expanded(flex: _flexSubmitted, child: Text(date.format(p.submittedAt))),
              // Shrinks the pill rather than overflowing a narrow column
              Expanded(
                flex: _flexStatus,
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _StatusPill(p.status)),
              ),

              // View and more options
              SizedBox(
                width: _actionsWidth,
                child: Row(
                  children: [
                    // Flexible so the button gives way instead of overflowing
                    Flexible(
                      child: OutlinedButton(
                        onPressed: onView,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('View', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        final text = value == 'phm' ? p.displayId : p.ltoNumber;
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text copied.')));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'phm', child: Text('Copy PHM number')),
                        PopupMenuItem(value: 'lto', child: Text('Copy LTO number')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Rounded status label with a coloured dot, like the design
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending_approval' => ('Pending', AppColors.warning),
      'active' => ('Active', AppColors.primary),
      'rejected' => ('Rejected', AppColors.danger),
      _ => ('Inactive', AppColors.neutral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Previous / next page button
class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.border),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
