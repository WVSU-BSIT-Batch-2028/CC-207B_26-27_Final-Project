
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'edit_inventory_drawer.dart';
import 'import/inventory_import_upload_screen.dart';

import '../../../models/inventory_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_data_table.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/tablet/tablet_filter_panel.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// The pharmacy's inventory list with search, filters and stock actions
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({
    super.key,
    this.onAddEntry,
    this.onEditItem,
    this.onImportTap,
  });

  final VoidCallback? onAddEntry;
  final ValueChanged<InventoryItem>? onEditItem;
  final VoidCallback? onImportTap;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';
  String _listing = 'all';
  final Set<String> _availability = {};
  final Set<String> _selectedIds = {};
  bool _onlyOutOfStock = false;
  bool _onlyRx = false;
  bool _showFilters = false;
  bool _busy = false;

  static const _availabilityLabels = {
    'available': 'Available',
    'low_stock': 'Low Stock',
    'unavailable': 'Unavailable',
    'unconfirmed': 'Unconfirmed',
  };

  // How many filters are switched on
  int get _activeFilterCount =>
      _availability.length +
      (_listing != 'all' ? 1 : 0) +
      (_onlyOutOfStock ? 1 : 0) +
      (_onlyRx ? 1 : 0);

  // Keep only the rows that match the search and the filters
  List<InventoryItem> _filtered(List<InventoryItem> all) {
    final query = _search.trim().toLowerCase();
    return all.where((item) {
      if (query.isNotEmpty &&
          !item.brandName.toLowerCase().contains(query) &&
          !item.genericName.toLowerCase().contains(query)) {
        return false;
      }
      if (_listing == 'active' && !item.isActive) return false;
      if (_listing == 'inactive' && item.isActive) return false;
      if (_availability.isNotEmpty &&
          !_availability.contains(item.availability)) {
        return false;
      }
      if (_onlyOutOfStock && !item.outOfStock) return false;
      if (_onlyRx && !item.isRx) return false;
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _listing = 'all';
      _availability.clear();
      _onlyOutOfStock = false;
      _onlyRx = false;
    });
  }

  // Today shows the time only; older dates show the day too
  String _formatUpdated(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay
        ? 'Today, ${DateFormat('h:mm a').format(local)}'
        : DateFormat('MMM d, h:mm a').format(local);
  }

  // Turns a database error into a short message for staff
  String _friendly(Object error) {
    try {
      final message = (error as dynamic).message;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Something went wrong. Please try again.';
  }

  // Runs one change, then reloads the list and tells the user what happened
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _selectedIds.clear();
      ref.invalidate(inventoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inventory updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _names(List<InventoryItem> items) =>
      items.map((i) => '${i.brandName} ${i.strength}').join(', ');

  Future<void> _markOutOfStock(List<InventoryItem> items) async {
    final ok = await showTabletConfirmDialog(
      context: context,
      title: items.length == 1
          ? 'Mark 1 medicine out of stock?'
          : 'Mark ${items.length} medicines out of stock?',
      targetName: _names(items),
      consequences: const [
        'Patients see it as Unavailable right away and can\'t reserve it.',
        'Your recorded count is kept for history. It isn\'t changed to 0.',
        'Confirmed reservations keep their held units. Check them if the '
            'shelf is truly empty.',
        'CSV/Excel imports won\'t switch this off. Use Back in stock when '
            'the shelf is refilled.',
      ],
      confirmLabel: 'Mark out of stock',
      isDanger: true,
    );
    if (ok != true) return;
    await _run(
      () => ref.read(inventoryServiceProvider).setOutOfStock([
        for (final i in items) i.id,
      ]),
    );
  }

  Future<void> _backInStock(List<InventoryItem> items) async {
    final counts = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BackInStockDialog(items: items),
    );
    if (counts == null || counts.isEmpty) return;
    await _run(() => ref.read(inventoryServiceProvider).backInStock(counts));
  }

  Future<void> _setActive(List<InventoryItem> items, bool active) async {
    if (!active) {
      final ok = await showTabletConfirmDialog(
        context: context,
        title: items.length == 1
            ? 'Deactivate 1 listing?'
            : 'Deactivate ${items.length} listings?',
        targetName: _names(items),
        consequences: const [
          'Hidden from patients: not in search, on your pharmacy page, or in '
              'carts.',
          'New reservations are blocked. Reservations already made aren\'t '
              'affected.',
          'Stays in Inventory under the Inactive filter, with its stock and '
              'history.',
          'You can activate it again anytime.',
          'Still selling it and the shelf is just empty? Use Mark out of '
              'stock instead.',
        ],
        confirmLabel: 'Deactivate',
        isDanger: true,
      );
      if (ok != true) return;
    } else {
      final ok = await showTabletConfirmDialog(
        context: context,
        title: items.length == 1
            ? 'Activate 1 listing?'
            : 'Activate ${items.length} listings?',
        targetName: _names(items),
        consequences: const [
          'Patients can see it and reserve it again.',
          'The last recorded stock is shown. Edit it first if it changed.',
        ],
        confirmLabel: 'Activate',
      );
      if (ok != true) return;
    }
    await _run(
      () => ref.read(inventoryServiceProvider).setListingActive([
        for (final i in items) i.id,
      ], active),
    );
  }

  Future<void> _showEditDrawer(InventoryItem item) async {
    final screenSize = MediaQuery.of(context).size;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close edit inventory drawer',
      barrierColor: Colors.black54,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            color: AppColors.surface,
            child: SizedBox(
              width: screenSize.width < 420 ? screenSize.width : 420,
              height: screenSize.height,
              child: EditInventoryDrawer(item: item),
            ),
          ),
        );
      },
    );
  }

  // Opens the import screen while preserving an optional parent callback.
  void _openImport() {
    if (widget.onImportTap != null) {
      widget.onImportTap!();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InventoryImportUploadScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);

    return AsyncView<List<InventoryItem>>(
      value: inventory,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'No inventory entries yet. Add your first medicine.',
      onRetry: () => ref.invalidate(inventoryProvider),
      builder: _buildInventory,
    );
  }

  Widget _buildInventory(List<InventoryItem> all) {
    final shown = _filtered(all);
    final selectedItems = all
        .where((i) => _selectedIds.contains(i.id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // The table keeps a usable height; short screens scroll the page
        final tableHeight = (constraints.maxHeight - 250).clamp(420.0, 2000.0);

        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                'MediTech isn\'t connected to your POS. '
                                'Update stock here, or import a CSV or Excel '
                                'file.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openImport,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Import CSV/Excel'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: widget.onAddEntry,
                          icon: const Icon(Icons.add),
                          label: const Text('Add inventory entry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: tableHeight,
                      child: TabletDataTable<InventoryItem>(
                        searchHint: 'Search medicine',
                        onSearchChanged: (v) => setState(() => _search = v),
                        totalCount: all.length,
                        filteredCount: shown.length,
                        countLabel: 'medicines',
                        onFiltersTap: () =>
                            setState(() => _showFilters = !_showFilters),
                        activeFilterCount: _activeFilterCount,
                        selectable: true,
                        selectedIds: _selectedIds,
                        idGetter: (item) => item.id,
                        onSelectionChanged: (ids) => setState(() {
                          _selectedIds
                            ..clear()
                            ..addAll(ids);
                        }),
                        bulkActions: [
                          _bulkButton(
                            'Mark out of stock',
                            background: AppColors.dangerLight,
                            foreground: AppColors.danger,
                            onTap: _busy
                                ? null
                                : () => _markOutOfStock(selectedItems),
                          ),
                          const SizedBox(width: 8),
                          _bulkButton(
                            'Back in stock',
                            background: AppColors.primaryLight,
                            foreground: AppColors.primary,
                            onTap: _busy
                                ? null
                                : () => _backInStock(selectedItems),
                          ),
                          const SizedBox(width: 8),
                          _bulkButton(
                            'Deactivate',
                            background: Colors.transparent,
                            foreground: Colors.white,
                            outlined: true,
                            onTap: _busy
                                ? null
                                : () => _setActive(selectedItems, false),
                          ),
                        ],
                        columns: const [
                          TabletColumn(title: 'MEDICINE', width: 240),
                          TabletColumn(title: 'STRENGTH', width: 110),
                          TabletColumn(title: 'FORM', width: 130),
                          TabletColumn(title: 'UNIT', width: 100),
                          TabletColumn(title: 'STOCK', width: 80),
                          TabletColumn(title: 'HELD', width: 80),
                          TabletColumn(title: 'AVAILABILITY', width: 140),
                          TabletColumn(title: 'PRICE / UNIT', width: 120),
                          TabletColumn(title: 'LAST UPDATED', width: 170),
                          TabletColumn(title: 'OUT OF STOCK', width: 130),
                          TabletColumn(title: 'STATUS', width: 110),
                          TabletColumn(title: 'ACTIONS', width: 220),
                        ],
                        items: shown,
                        rowBuilder: (context, item, index) => [
                          _medicineCell(item),
                          Text(item.strength),
                          Text(item.dosageForm),
                          Text(item.unit),
                          Text(
                            '${item.stockQuantity}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('${item.heldQuantity}'),
                          StatusBadge.availability(item.availability),
                          Text(
                            '₱${item.pricePerUnit.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _formatUpdated(item.stockConfirmedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          _outOfStockSwitch(item),
                          item.isActive
                              ? const StatusBadge(
                                  'Active',
                                  tone: BadgeTone.success,
                                )
                              : const StatusBadge('Inactive'),
                          _actionsCell(item),
                        ],
                        emptyState: const Center(
                          child: Text(
                            'No matching medicines found.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Row(
                      children: [
                        Expanded(
                          child: _ExplainerCard(
                            title: 'Out of stock switch',
                            body:
                                'For an empty shelf. The medicine stays '
                                'listed but shows as Unavailable, and '
                                'patients can\'t reserve it. "Back in stock" '
                                'asks you to count the shelf and enter the '
                                'new quantity.',
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ExplainerCard(
                            title: 'Deactivate',
                            body:
                                'For a medicine you stopped carrying. It\'s '
                                'hidden from patients completely, but it '
                                'stays here under the Inactive filter so you '
                                'can activate it again.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_showFilters) ...[
              // Tapping outside closes the panel
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showFilters = false),
                ),
              ),
              Positioned(
                top: 150,
                right: AppSpacing.lg,
                child: TabletFilterPanel(
                  title: 'Filter inventory',
                  activeFilterCount: _activeFilterCount,
                  onReset: _resetFilters,
                  onApply: () => setState(() => _showFilters = false),
                  content: _filterContent(all),
                ),
              ),
            ],
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black12,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  // A button for the dark bulk bar
  Widget _bulkButton(
    String label, {
    required Color background,
    required Color foreground,
    required VoidCallback? onTap,
    bool outlined = false,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: Colors.white38,
        side: outlined ? const BorderSide(color: Colors.white54) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Name with the generic name underneath, plus an Rx badge when needed
  Widget _medicineCell(InventoryItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                item.brandName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (item.isRx) ...[
              const SizedBox(width: 6),
              const StatusBadge.rx(),
            ],
          ],
        ),
        Text(
          item.genericName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // On asks for confirmation; off asks staff to count the shelf
  Widget _outOfStockSwitch(InventoryItem item) {
    return Switch(
      value: item.outOfStock,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.danger
            : AppColors.border,
      ),
      onChanged: _busy
          ? null
          : (on) => on ? _markOutOfStock([item]) : _backInStock([item]),
    );
  }

  // Edit and Deactivate (or Activate) side by side
  Widget _actionsCell(InventoryItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => widget.onEditItem != null
                    ? widget.onEditItem!(item)
                    : _showEditDrawer(item),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: const Text('Edit'),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _busy ? null : () => _setActive([item], !item.isActive),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: item.isActive
                ? AppColors.danger
                : AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: Text(
            item.isActive ? 'Deactivate' : 'Activate',
          ),
        ),
      ],
    );
  }

  // The pills and checkboxes inside the filter panel
  Widget _filterContent(List<InventoryItem> all) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LISTING STATUS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final value in ['all', 'active', 'inactive'])
              ChoiceChip(
                label: Text(value[0].toUpperCase() + value.substring(1)),
                selected: _listing == value,
                onSelected: (_) => setState(() => _listing = value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'AVAILABILITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        for (final entry in _availabilityLabels.entries)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(entry.value),
            secondary: Text(
              '${all.where((i) => i.availability == entry.key).length}',
            ),
            value: _availability.contains(entry.key),
            onChanged: (checked) => setState(() {
              if (checked == true) {
                _availability.add(entry.key);
              } else {
                _availability.remove(entry.key);
              }
            }),
          ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Only medicines marked out of stock'),
          value: _onlyOutOfStock,
          onChanged: (v) => setState(() => _onlyOutOfStock = v == true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Only Rx medicines'),
          value: _onlyRx,
          onChanged: (v) => setState(() => _onlyRx = v == true),
        ),
      ],
    );
  }
}

// Staff count the shelf; the new number replaces the recorded stock
class _BackInStockDialog extends StatefulWidget {
  const _BackInStockDialog({required this.items});

  final List<InventoryItem> items;

  @override
  State<_BackInStockDialog> createState() => _BackInStockDialogState();
}

class _BackInStockDialogState extends State<_BackInStockDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final item in widget.items)
      item.id: TextEditingController(text: '${item.stockQuantity}'),
  };
  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Whole number, at least 1, and not below the units held for reservations
  void _save() {
    final result = <String, int>{};
    final errors = <String, String?>{};
    for (final item in widget.items) {
      final value = int.tryParse(_controllers[item.id]!.text.trim());
      if (value == null || value < 1) {
        errors[item.id] = 'Enter a whole number of at least 1.';
      } else if (value < item.heldQuantity) {
        errors[item.id] = 'Not lower than the ${item.heldQuantity} units held.';
      } else {
        result[item.id] = value;
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark back in stock'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Count what\'s on the shelf and enter the quantity. MediTech '
                'isn\'t connected to your POS, so it doesn\'t restore an old '
                'count or calculate one. Your number replaces the recorded '
                'stock, and availability is worked out from it.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final item in widget.items)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.brandName} ${item.strength}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last recorded: ${item.stockQuantity} '
                              '${item.unit}s',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 170,
                        child: TextField(
                          controller: _controllers[item.id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity on shelf',
                            errorText: _errors[item.id],
                            errorMaxLines: 2,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'After saving: the Out of Stock switch turns off, Last '
                'updated becomes now, and patients can reserve it again.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save and show to patients'),
        ),
      ],
    );
  }
}

// Short note under the table explaining out of stock vs. deactivate
class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
