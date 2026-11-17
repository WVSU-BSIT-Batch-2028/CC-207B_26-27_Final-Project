
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/inventory_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

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
  ConsumerState<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String searchQuery = '';
  String listingFilter = 'all';
  final Set<String> selectedIds = {};

  final Set<String> availabilityFilters = {};

  bool outOfStockOnly = false;
  bool prescriptionOnly = false;
  bool showFilters = false;
  bool isProcessing = false;

  List<InventoryItem> filterItems(List<InventoryItem> items) {
    return items.where((item) {
      final query = searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          item.brandName.toLowerCase().contains(query) ||
          item.genericName.toLowerCase().contains(query);

      final matchesListing = listingFilter == 'all' ||
          (listingFilter == 'active' && item.isActive) ||
          (listingFilter == 'inactive' && !item.isActive);

      final matchesAvailability = availabilityFilters.isEmpty ||
          availabilityFilters.contains(item.availability);

      final matchesOutOfStock = !outOfStockOnly ||
          item.outOfStock ||
          item.availableQuantity <= 0;

      final matchesPrescription = !prescriptionOnly || item.isRx;

      return matchesSearch &&
          matchesListing &&
          matchesAvailability &&
          matchesOutOfStock &&
          matchesPrescription;
    }).toList();
  }

  int get activeFilterCount {
    var count = availabilityFilters.length;
    if (listingFilter != 'all') count++;
    if (outOfStockOnly) count++;
    if (prescriptionOnly) count++;
    return count;
  }

  void refreshInventory() {
    ref.invalidate(inventoryProvider);
  }

  Future<void> runAction(Future<void> Function() action) async {
    setState(() => isProcessing = true);

    try {
      await action();
      selectedIds.clear();
      refreshInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update inventory: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  Future<void> markOutOfStock(List<String> ids) async {
    await runAction(() async {
      await ref.read(inventoryServiceProvider).setOutOfStock(ids);
    });
  }

  Future<void> deactivateSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate selected listings?'),
        content: const Text(
          'These medicines will be hidden from patients. '
          'You can activate them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await runAction(() async {
      await ref
          .read(inventoryServiceProvider)
          .setListingActive(selectedIds.toList(), false);
    });
  }

  Future<void> activateItem(InventoryItem item) async {
    await runAction(() async {
      await ref
          .read(inventoryServiceProvider)
          .setListingActive([item.id], true);
    });
  }

  Future<void> backInStock(InventoryItem item) async {
    final controller = TextEditingController(
      text: item.stockQuantity.toString(),
    );

    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark back in stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.brandName} ${item.strength}'),
            const SizedBox(height: AppSpacing.md),
            const Text('Quantity currently on shelf'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (quantity == null) return;

    await runAction(() async {
      await ref.read(inventoryServiceProvider).backInStock({
        item.id: quantity,
      });
    });
  }

  void resetFilters() {
    setState(() {
      listingFilter = 'all';
      availabilityFilters.clear();
      outOfStockOnly = false;
      prescriptionOnly = false;
    });
  }

  Widget buildFilterPanel() {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter inventory',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: resetFilters,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'LISTING STATUS',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              children: [
                for (final value in ['all', 'active', 'inactive'])
                  ChoiceChip(
                    label: Text(
                      value[0].toUpperCase() + value.substring(1),
                    ),
                    selected: listingFilter == value,
                    onSelected: (_) {
                      setState(() => listingFilter = value);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'AVAILABILITY',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in {
              'available': 'Available',
              'low_stock': 'Low Stock',
              'unavailable': 'Unavailable',
              'unconfirmed': 'Unconfirmed',
            }.entries)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: availabilityFilters.contains(entry.key),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      availabilityFilters.add(entry.key);
                    } else {
                      availabilityFilters.remove(entry.key);
                    }
                  });
                },
              ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Only medicines marked out of stock'),
              value: outOfStockOnly,
              onChanged: (value) {
                setState(() => outOfStockOnly = value ?? false);
              },
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Only Rx medicines'),
              value: prescriptionOnly,
              onChanged: (value) {
                setState(() => prescriptionOnly = value ?? false);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  setState(() => showFilters = false);
                },
                child: const Text('Show results'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBulkActions() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF17251D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${selectedIds.length} selected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          OutlinedButton(
            onPressed: isProcessing
                ? null
                : () => markOutOfStock(selectedIds.toList()),
            child: const Text('Mark out of stock'),
          ),
          OutlinedButton(
            onPressed: isProcessing
                ? null
                : () => showBulkBackInStockDialog(),
            child: const Text('Back in stock'),
          ),
          OutlinedButton(
            onPressed: isProcessing ? null : deactivateSelected,
            child: const Text('Deactivate'),
          ),
          TextButton(
            onPressed: () => setState(selectedIds.clear),
            child: const Text(
              'Clear selection',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showBulkBackInStockDialog() async {
    final items = ref.read(inventoryProvider).asData?.value ?? <InventoryItem>[];
    final selectedItems =
        items.where((item) => selectedIds.contains(item.id)).toList();

    final controllers = {
      for (final item in selectedItems)
        item.id: TextEditingController(
          text: item.stockQuantity.toString(),
        ),
    };

    final quantities = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mark back in stock'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in selectedItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.brandName} ${item.strength}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextField(
                            controller: controllers[item.id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity on shelf',
                            ),
                          ),
                        ],
                      ),
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
              onPressed: () {
                final result = <String, int>{};

                for (final item in selectedItems) {
                  final value = int.tryParse(
                    controllers[item.id]!.text,
                  );
                  if (value == null || value < 0) return;
                  result[item.id] = value;
                }

                Navigator.pop(context, result);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }

    if (quantities == null || quantities.isEmpty) return;

    await runAction(() async {
      await ref.read(inventoryServiceProvider).backInStock(quantities);
    });
  }

  Widget buildInventoryTable(List<InventoryItem> allItems) {
    final items = filterItems(allItems);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
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
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'MediTech isn’t connected to your POS. '
                          'Update stock here, or import a CSV or Excel file.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onImportTap,
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search medicine',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => showFilters = !showFilters);
                    },
                    icon: const Icon(Icons.filter_list),
                    label: Text(
                      activeFilterCount > 0
                          ? 'Filters ($activeFilterCount)'
                          : 'Filters',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${items.length} of ${allItems.length} medicines',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (selectedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: buildBulkActions(),
              ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No medicines match your search or filters.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor:
                                  WidgetStateProperty.all(
                                const Color(0xFFF8FAF8),
                              ),
                              dataRowMinHeight: 58,
                              dataRowMaxHeight: 68,
                              columnSpacing: 24,
                              columns: [
                                DataColumn(
                                  label: Checkbox(
                                    value: items.isNotEmpty &&
                                        items.every(
                                          (item) =>
                                              selectedIds.contains(item.id),
                                        ),
                                    tristate: true,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedIds.addAll(
                                            items.map((item) => item.id),
                                          );
                                        } else {
                                          selectedIds.removeAll(
                                            items.map((item) => item.id),
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const DataColumn(label: Text('MEDICINE')),
                                const DataColumn(label: Text('STRENGTH')),
                                const DataColumn(label: Text('FORM')),
                                const DataColumn(label: Text('UNIT')),
                                const DataColumn(label: Text('STOCK')),
                                const DataColumn(label: Text('HELD')),
                                const DataColumn(label: Text('AVAILABILITY')),
                                const DataColumn(label: Text('PRICE / UNIT')),
                                const DataColumn(label: Text('LAST UPDATED')),
                                const DataColumn(label: Text('OUT OF STOCK')),
                                const DataColumn(label: Text('STATUS')),
                                const DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: items.map((item) {
                                return DataRow(
                                  selected: selectedIds.contains(item.id),
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: selectedIds.contains(item.id),
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              selectedIds.add(item.id);
                                            } else {
                                              selectedIds.remove(item.id);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 125,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.brandName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              item.genericName,
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(item.strength)),
                                    DataCell(Text(item.dosageForm)),
                                    DataCell(Text(item.unit)),
                                    DataCell(Text('${item.stockQuantity}')),
                                    DataCell(Text('${item.heldQuantity}')),
                                    DataCell(
                                      StatusBadge.availability(
                                        item.availability,
                                      ),
                                    ),
                                    DataCell(
                                      Text('₱${item.pricePerUnit}'),
                                    ),
                                    DataCell(
                                      Text(
                                        item.stockConfirmedAt
                                          .toLocal()
                                          .toString()
                                          .substring(0, 16),
                                      ),
                                    ),
                                    DataCell(
                                      Switch(
                                        value: item.outOfStock,
                                        onChanged: isProcessing
                                            ? null
                                            : (value) {
                                                if (value) {
                                                  markOutOfStock([item.id]);
                                                } else {
                                                  backInStock(item);
                                                }
                                              },
                                      ),
                                    ),
                                    DataCell(
                                      StatusBadge.availability(
                                        item.isActive
                                            ? 'available'
                                            : 'unconfirmed',
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            onPressed: widget.onEditItem == null
                                                ? null
                                                : () => widget.onEditItem!(item),
                                            child: const Text('Edit'),
                                          ),
                                          const SizedBox(width: 6),
                                          TextButton(
                                            onPressed: isProcessing
                                                ? null
                                                : () {
                                                    if (item.isActive) {
                                                      setState(() {
                                                        selectedIds
                                                          ..clear()
                                                          ..add(item.id);
                                                      });
                                                      deactivateSelected();
                                                    } else {
                                                      activateItem(item);
                                                    }
                                                  },
                                            child: Text(
                                              item.isActive
                                                  ? 'Deactivate'
                                                  : 'Activate',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _infoCard(
                      'Out of stock switch',
                      'For an empty shelf. The medicine stays listed '
                          'but shows as Unavailable, and patients can’t '
                          'reserve it. Use Back in stock when refilled.',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _infoCard(
                      'Deactivate',
                      'For a medicine you stopped carrying. It is hidden '
                          'from patients but stays here under the Inactive '
                          'filter so you can activate it again.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showFilters)
          Positioned(
            top: 100,
            left: 250,
            child: buildFilterPanel(),
          ),
        if (isProcessing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
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
      onRetry: refreshInventory,
      builder: buildInventoryTable,
    );
  }
}
