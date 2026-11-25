import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/inventory_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/stock_alerts_providers.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

class EditInventoryDrawer extends ConsumerStatefulWidget {
  const EditInventoryDrawer({
    super.key,
    required this.item,
    this.onClose,
  });

  final InventoryItem item;
  final VoidCallback? onClose;

  @override
  ConsumerState<EditInventoryDrawer> createState() =>
      _EditInventoryDrawerState();
}

class _EditInventoryDrawerState
    extends ConsumerState<EditInventoryDrawer> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _stockController;
  late final TextEditingController _priceController;
  late final TextEditingController _thresholdController;

  DateTime? _expiryDate;
  bool _clearExpiry = false;
  bool _isSaving = false;

  InventoryItem get item => widget.item;

  @override
  void initState() {
    super.initState();

    _stockController = TextEditingController(
      text: item.stockQuantity.toString(),
    );
    _priceController = TextEditingController(
      text: item.pricePerUnit.toStringAsFixed(2),
    );
    _thresholdController = TextEditingController(
      text: item.lowStockThreshold.toString(),
    );

    _expiryDate = item.nearestExpiry;
  }

  @override
  void dispose() {
    _stockController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  int get _previewStock =>
      int.tryParse(_stockController.text) ?? item.stockQuantity;

  int get _previewThreshold =>
      int.tryParse(_thresholdController.text) ??
      item.lowStockThreshold;

  void _closeDrawer() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  String get _availabilityPreview {
    if (item.outOfStock) return 'Unavailable';

    final available = _previewStock - item.heldQuantity;

    if (available <= 0) return 'Unavailable';

    final stockWasChanged = _previewStock != item.stockQuantity;
    final confirmedAt = stockWasChanged
        ? DateTime.now()
        : item.stockConfirmedAt;

    if (confirmedAt.isBefore(
      DateTime.now().subtract(const Duration(days: 7)),
    )) {
      return 'Unconfirmed';
    }

    if (available <= _previewThreshold) return 'Low Stock';

    return 'Available';
  }

  Color get _availabilityColor {
    switch (_availabilityPreview) {
      case 'Available':
        return AppColors.primary;
      case 'Low Stock':
        return Colors.orange.shade800;
      case 'Unavailable':
        return Colors.red.shade700;
      default:
        return AppColors.textMuted;
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _clearExpiry = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$month/$day/${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final stock = int.parse(_stockController.text);
    final price = double.parse(_priceController.text);
    final threshold = int.parse(_thresholdController.text);

    if (stock < item.heldQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock cannot be lower than ${item.heldQuantity} '
            'units held for reservations.',
          ),
        ),
      );
      return;
    }

    final stockChanged = stock != item.stockQuantity;
    final priceChanged = price != item.pricePerUnit;
    final thresholdChanged = threshold != item.lowStockThreshold;

    final expiryChanged = _clearExpiry ||
        _expiryDate != item.nearestExpiry;

    if (!stockChanged &&
        !priceChanged &&
        !thresholdChanged &&
        !expiryChanged) {
      _closeDrawer();
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(inventoryServiceProvider).updateItem(
            itemId: item.id,
            stockQuantity: stockChanged ? stock : null,
            price: priceChanged ? price : null,
            lowStockThreshold:
                thresholdChanged ? threshold : null,
            nearestExpiry: expiryChanged && !_clearExpiry
                ? _expiryDate
                : null,
            clearExpiry: _clearExpiry,
          );

      ref.invalidate(inventoryProvider);
      ref.invalidate(stockAlertsProvider);

      if (!mounted) return;

      _closeDrawer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory entry updated successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update inventory: $error'),
        ),
      );
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.number,
    List<TextInputFormatter>? inputFormatters,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixText: prefix,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit ${item.brandName} ${item.strength}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isSaving
                        ? null
                        : _closeDrawer,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildField(
                        label: 'Stock quantity',
                        controller: _stockController,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          final quantity = int.tryParse(value ?? '');

                          if (quantity == null) {
                            return 'Enter a valid whole number.';
                          }
                          if (quantity < 0) {
                            return 'Stock cannot be negative.';
                          }
                          if (quantity < item.heldQuantity) {
                            return 'At least ${item.heldQuantity} units '
                                'are held for reservations.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildField(
                        label: 'Price per unit (₱)',
                        controller: _priceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final price = double.tryParse(value ?? '');

                          if (price == null || price <= 0) {
                            return 'Enter a price above zero.';
                          }
                          if ((price * 100).round() !=
                              (price * 100)) {
                            return 'Use at most 2 decimal places.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildField(
                        label: 'Low-stock threshold',
                        controller: _thresholdController,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          final threshold = int.tryParse(value ?? '');

                          if (threshold == null || threshold < 1) {
                            return 'Threshold must be 1 or more.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Nearest expiry date (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: _isSaving ? null : _pickExpiryDate,
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 15,
                          ),
                          side: const BorderSide(
                            color: AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _expiryDate == null
                                    ? 'Select expiry date'
                                    : _formatDate(_expiryDate!),
                                style: const TextStyle(
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      if (_expiryDate != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _expiryDate = null;
                                      _clearExpiry = true;
                                    });
                                  },
                            child: const Text('Clear expiry date'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Used for the Expiring soon alert.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Patients will see:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            Text(
                              _availabilityPreview,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _availabilityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}