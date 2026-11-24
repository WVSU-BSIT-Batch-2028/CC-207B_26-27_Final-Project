import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/inventory_item.dart';
import '../../../models/stock_alert_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/stock_alerts_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../inventory/edit_inventory_drawer.dart';

// Stock Alerts screen displaying 4 live alert categories (Ph-30 to Ph-32)
class StockAlertsScreen extends ConsumerStatefulWidget {
  const StockAlertsScreen({
    super.key,
    this.onEditStock,
    this.onBackInStock,
    this.onOpenInventory,
  });

  final ValueChanged<StockAlertItem>? onEditStock;
  final ValueChanged<StockAlertItem>? onBackInStock;
  final VoidCallback? onOpenInventory;

  @override
  ConsumerState<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends ConsumerState<StockAlertsScreen> {
  // Shortcut for 'Edit stock' action (Ph-30)
  Future<void> _handleEditStock(StockAlertItem item) async {
    if (widget.onEditStock != null) {
      widget.onEditStock!(item);
      return;
    }

    InventoryItem fullItem;
    try {
      final items = await ref.read(inventoryServiceProvider).loadInventory();
      fullItem = items.firstWhere(
        (it) => it.id == item.inventoryItemId,
        orElse: () => InventoryItem(
          id: item.inventoryItemId,
          displayId: 'INV-${item.id.padLeft(6, '0')}',
          medicineId: item.medicineId,
          brandName: item.brandName,
          genericName: item.genericName,
          strength: item.strength,
          dosageForm: item.dosageForm,
          unit: item.unit,
          isRx: false,
          stockQuantity: item.stockQuantity,
          heldQuantity: item.heldQuantity,
          pricePerUnit: 0,
          lowStockThreshold: item.lowStockThreshold,
          outOfStock: item.outOfStock,
          isActive: true,
          nearestExpiry: item.nearestExpiry,
          stockConfirmedAt: item.stockConfirmedAt ?? DateTime.now(),
        ),
      );
    } catch (_) {
      fullItem = InventoryItem(
        id: item.inventoryItemId,
        displayId: 'INV-000001',
        medicineId: item.medicineId,
        brandName: item.brandName,
        genericName: item.genericName,
        strength: item.strength,
        dosageForm: item.dosageForm,
        unit: item.unit,
        isRx: false,
        stockQuantity: item.stockQuantity,
        heldQuantity: item.heldQuantity,
        pricePerUnit: 0,
        lowStockThreshold: item.lowStockThreshold,
        outOfStock: item.outOfStock,
        isActive: true,
        nearestExpiry: item.nearestExpiry,
        stockConfirmedAt: item.stockConfirmedAt ?? DateTime.now(),
      );
    }

    if (!mounted) return;

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
              child: EditInventoryDrawer(item: fullItem),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: anim.drive(tween),
          child: child,
        );
      },
    );

    if (mounted) {
      ref.invalidate(stockAlertsProvider);
      ref.invalidate(inventoryProvider);
    }
  }

  // Shortcut for 'Back in stock' shelf-count dialog (Ph-32, Ph-25)
  Future<void> _handleBackInStock(StockAlertItem item) async {
    if (widget.onBackInStock != null) {
      widget.onBackInStock!(item);
      return;
    }

    final controller = TextEditingController(text: '${item.stockQuantity}');
    String? error;

    final newCount = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Mark back in stock'),
              content: SizedBox(
                width: 480,
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
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: error != null
                                ? AppColors.danger
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.medicineDisplayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last recorded: ${item.stockQuantity} ${item.unit}s',
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
                                  width: 120,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity on shelf',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (error != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    final val = int.tryParse(controller.text.trim());
                    if (val == null || val < 1) {
                      setDialogState(() => error = 'Enter at least 1');
                      return;
                    }
                    if (val < item.heldQuantity) {
                      setDialogState(() => error = 'Cannot be below ${item.heldQuantity} held');
                      return;
                    }
                    Navigator.pop(dialogCtx, val);
                  },
                  child: const Text('Save and show to patients'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (newCount == null) return;

    try {
      await ref.read(inventoryServiceProvider).backInStock({
        item.inventoryItemId: newCount,
      });
      ref.invalidate(stockAlertsProvider);
      ref.invalidate(inventoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.brandName} is now back in stock.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stock: $e')),
      );
    }
  }

  void _handleOpenInventory() {
    if (widget.onOpenInventory != null) {
      widget.onOpenInventory!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please navigate to the Inventory tab from the sidebar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(stockAlertsProvider);
    final activeTab = ref.watch(selectedAlertTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AsyncView<Map<StockAlertType, List<StockAlertItem>>>(
        value: alertsAsync,
        onRetry: () => ref.refresh(stockAlertsProvider),
        builder: (data) {
              final lowStockList = data[StockAlertType.lowStock] ?? [];
              final outOfStockList = data[StockAlertType.outOfStock] ?? [];
              final expiringList = data[StockAlertType.expiringSoon] ?? [];
              final notUpdatedList = data[StockAlertType.notUpdated] ?? [];

              final currentList = data[activeTab] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Title Area
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    color: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Alerts',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Medicines that need action now. Worked out live from your inventory with simple rules; nothing is predicted.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  // Category Cards (Ph-30)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AlertCategoryCard(
                            title: 'Low stock',
                            count: lowStockList.length,
                            subtitle: '1 up to your low-stock level available',
                            isSelected: activeTab == StockAlertType.lowStock,
                            onTap: () => ref.read(selectedAlertTabProvider.notifier).selectTab(
                                StockAlertType.lowStock),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _AlertCategoryCard(
                            title: 'Out of stock',
                            count: outOfStockList.length,
                            subtitle: 'None available, or the switch is on',
                            isSelected: activeTab == StockAlertType.outOfStock,
                            onTap: () => ref.read(selectedAlertTabProvider.notifier).selectTab(
                                StockAlertType.outOfStock),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _AlertCategoryCard(
                            title: 'Expiring soon',
                            count: expiringList.length,
                            subtitle: 'Nearest expiry within 60 days',
                            isSelected: activeTab == StockAlertType.expiringSoon,
                            onTap: () => ref.read(selectedAlertTabProvider.notifier).selectTab(
                                StockAlertType.expiringSoon),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _AlertCategoryCard(
                            title: 'Not updated',
                            count: notUpdatedList.length,
                            subtitle: 'No stock update in 7 days',
                            isSelected: activeTab == StockAlertType.notUpdated,
                            onTap: () => ref.read(selectedAlertTabProvider.notifier).selectTab(
                                StockAlertType.notUpdated),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              child: Text(
                                _sectionSummary(activeTab),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.border),

                            // Table header
                            _buildTableHeader(activeTab),
                            const Divider(height: 1, color: AppColors.border),

                            // List of alert items
                            Expanded(
                              child: currentList.isEmpty
                                  ? Center(
                                      child: Text(
                                        _emptyMessage(activeTab),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: currentList.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (context, index) {
                                        return _buildRow(
                                          context,
                                          currentList[index],
                                          activeTab,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Explainer footer note (matching wireframe Ph-30 to Ph-32)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'How alerts work: Low stock = 1 up to your low-stock level available · '
                        'Out of stock = none available, or the Out of Stock switch is on · '
                        'Expiring soon = nearest expiry within 60 days · '
                        'Not updated = no stock update in 7 days, so patients see Unconfirmed. '
                        'Alerts clear on their own once the stock is fixed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.4,
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

  String _sectionSummary(StockAlertType tab) {
    return switch (tab) {
      StockAlertType.lowStock => 'Low stock  Available stock is from 1 up to the low-stock level',
      StockAlertType.outOfStock => 'Out of stock  Available stock is 0, or the Out of Stock switch is on',
      StockAlertType.expiringSoon => 'Expiring soon  Nearest expiry date is within 60 days',
      StockAlertType.notUpdated => 'Not updated  Stock has not been confirmed or updated in 7 days',
    };
  }

  String _emptyMessage(StockAlertType tab) {
    return switch (tab) {
      StockAlertType.lowStock => 'No items currently at low stock level.',
      StockAlertType.outOfStock => 'No items currently marked out of stock.',
      StockAlertType.expiringSoon => 'No items expiring within 60 days.',
      StockAlertType.notUpdated => 'All item counts have been updated in the last 7 days.',
    };
  }

  Widget _buildTableHeader(StockAlertType tab) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(flex: 3, child: _ColText('MEDICINE')),
          const SizedBox(width: 80, child: _ColText('STOCK')),
          const SizedBox(width: 70, child: _ColText('HELD')),
          Expanded(
            flex: 2,
            child: _ColText(switch (tab) {
              StockAlertType.lowStock => 'LOW-STOCK LEVEL',
              StockAlertType.outOfStock => 'WHY',
              StockAlertType.expiringSoon => 'NEAREST EXPIRY',
              StockAlertType.notUpdated => 'LAST UPDATED',
            }),
          ),
          const SizedBox(width: 140, child: _ColText('LAST UPDATED')),
          const SizedBox(width: 130, child: _ColText('ACTION')),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, StockAlertItem item, StockAlertType tab) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineDisplayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  item.genericName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${item.stockQuantity}',
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${item.heldQuantity}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildConditionCell(item, tab),
          ),
          SizedBox(
            width: 140,
            child: Text(
              _formatDate(item.stockConfirmedAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            width: 130,
            child: _buildActionButton(context, item, tab),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCell(StockAlertItem item, StockAlertType tab) {
    switch (tab) {
      case StockAlertType.lowStock:
        return Text(
          '${item.availableStock} available · level ${item.lowStockThreshold}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.warning,
          ),
        );
      case StockAlertType.outOfStock:
        return Text(
          item.outOfStock ? 'Switch is on' : 'Stock is 0',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.danger,
          ),
        );
      case StockAlertType.expiringSoon:
        final days = item.nearestExpiry != null
            ? item.nearestExpiry!.difference(DateTime.now()).inDays
            : 0;
        return Text(
          '${_formatDate(item.nearestExpiry)} ($days days)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.warning,
          ),
        );
      case StockAlertType.notUpdated:
        return Text(
          'Unconfirmed (${_formatDate(item.stockConfirmedAt)})',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        );
    }
  }

  Widget _buildActionButton(BuildContext context, StockAlertItem item, StockAlertType tab) {
    switch (tab) {
      case StockAlertType.lowStock:
      case StockAlertType.notUpdated:
        return OutlinedButton(
          onPressed: () => _handleEditStock(item),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 32),
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Edit stock', style: TextStyle(fontSize: 12)),
        );
      case StockAlertType.outOfStock:
        return OutlinedButton(
          onPressed: () => _handleBackInStock(item),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 32),
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Back in stock', style: TextStyle(fontSize: 12)),
        );
      case StockAlertType.expiringSoon:
        return OutlinedButton(
          onPressed: _handleOpenInventory,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 32),
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Open in Inventory', style: TextStyle(fontSize: 12)),
        );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _ColText extends StatelessWidget {
  const _ColText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AlertCategoryCard extends StatelessWidget {
  const _AlertCategoryCard({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final int count;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
