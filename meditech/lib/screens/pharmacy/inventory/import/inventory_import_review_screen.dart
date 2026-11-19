
import 'package:flutter/material.dart';

import '../../../../services/inventory_import_service.dart';
import '../../../../widgets/common/status_badge.dart';
import '../../../../widgets/theme/app_colors.dart';
import '../../../../widgets/theme/app_spacing.dart';

// Ph-29: Staged import review. Existing RPC/service behavior is retained.
class InventoryImportReviewScreen extends StatefulWidget {
  InventoryImportReviewScreen({
    super.key,
    required this.batchId,
    InventoryImportService? service,
  }) : service = service ?? InventoryImportService();

  final String batchId;
  final InventoryImportService service;

  @override
  State<InventoryImportReviewScreen> createState() =>
      _InventoryImportReviewScreenState();
}

class _InventoryImportReviewScreenState
    extends State<InventoryImportReviewScreen> {
  Map<String, dynamic>? _batch;
  List<Map<String, dynamic>> _rows = [];

  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final batch = await widget.service.loadBatch(widget.batchId);
      final rows = await widget.service.loadRows(widget.batchId);

      if (!mounted) return;

      setState(() {
        _batch = batch;
        _rows = rows;
        _loading = false;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
        _working = false;
      });
    }
  }

  int get _validRows => _rows.where(_rowIsValid).length;

  int get _errorRows => _rows.length - _validRows;

  bool _rowIsValid(Map<String, dynamic> row) {
    final errors = row['errors'];
    return errors is List ? errors.isEmpty : true;
  }

  List<String> _messages(dynamic value) {
    return value is List
        ? value.map((e) => e.toString()).toList()
        : [];
  }

  String _disp(dynamic value) {
    return value == null || value.toString().isEmpty
        ? '—'
        : value.toString();
  }

  bool get _isReviewing => _batch?['status'] == 'reviewing';

  Future<void> _editRow(Map<String, dynamic> row) async {
    final result = await _showEditDialog(row);
    if (result == null) return;

    setState(() => _working = true);

    try {
      await widget.service.updateRow(
        rowId: row['id'].toString(),
        medicineLabel: result['medicine_label'] as String,
        stockQuantity: result['stock_quantity'] as int,
        pricePerUnit: result['price_per_unit'] as double,
        lowStockThreshold: result['low_stock_threshold'] as int?,
        nearestExpiry: result['nearest_expiry'] as DateTime?,
      );

      await _loadReview();

      if (mounted) {
        _snack('Row updated.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not update row: $error');
      }
    }
  }

  Future<Map<String, dynamic>?> _showEditDialog(
    Map<String, dynamic> row,
  ) async {
    final medicine = TextEditingController(
      text: _disp(row['medicine_label']),
    );

    final stock = TextEditingController(
      text: _disp(row['stock_quantity']),
    );

    final price = TextEditingController(
      text: _disp(row['price_per_unit']),
    );

    final threshold = TextEditingController(
      text: row['low_stock_threshold']?.toString() ?? '',
    );

    DateTime? expiry = row['nearest_expiry'] == null
        ? null
        : DateTime.tryParse(row['nearest_expiry'].toString());

    String? validationError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit row ${row['source_row_number'] ?? ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogField(
                    controller: medicine,
                    label: 'Medicine (brand and strength)',
                  ),
                  _DialogField(
                    controller: stock,
                    label: 'Stock quantity',
                    keyboardType: TextInputType.number,
                  ),
                  _DialogField(
                    controller: price,
                    label: 'Price per unit',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _DialogField(
                    controller: threshold,
                    label: 'Low-stock threshold (optional)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expiry == null
                              ? 'Nearest expiry: Not set'
                              : 'Nearest expiry: ${_dateString(expiry!)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: ctx,
                            initialDate: expiry ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (selected != null) {
                            setDialogState(() => expiry = selected);
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                      if (expiry != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () {
                            setDialogState(() => expiry = null);
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  if (validationError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          validationError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: () {
                final medicineValue = medicine.text.trim();
                final stockValue = int.tryParse(stock.text.trim());

                final priceText = price.text.trim();
                final priceValue = double.tryParse(priceText);

                final thresholdText = threshold.text.trim();
                final thresholdValue = thresholdText.isEmpty
                    ? null
                    : int.tryParse(thresholdText);

                final priceFormat =
                    RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(priceText);

                if (medicineValue.isEmpty ||
                    stockValue == null ||
                    stockValue < 0 ||
                    stockValue > 2147483647 ||
                    priceValue == null ||
                    !priceFormat ||
                    priceValue <= 0 ||
                    priceValue > 9999999999.99 ||
                    (thresholdText.isNotEmpty &&
                        (thresholdValue == null ||
                            thresholdValue < 1 ||
                            thresholdValue > 2147483647))) {
                  setDialogState(() {
                    validationError =
                        'Enter a medicine name, valid stock, positive '
                        'price (up to 2 decimals), and optional '
                        'threshold of at least 1.';
                  });
                  return;
                }

                Navigator.pop(dialogContext, {
                  'medicine_label': medicineValue,
                  'stock_quantity': stockValue,
                  'price_per_unit': priceValue,
                  'low_stock_threshold': thresholdValue,
                  'nearest_expiry': expiry,
                });
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    medicine.dispose();
    stock.dispose();
    price.dispose();
    threshold.dispose();

    return result;
  }

  Future<void> _removeRow(Map<String, dynamic> row) async {
    final confirmed = await _confirm(
      title: 'Remove row?',
      message: 'This row will be removed from the import batch.',
      confirmText: 'Remove',
      danger: true,
    );

    if (!confirmed) return;

    setState(() => _working = true);

    try {
      await widget.service.removeRow(row['id'].toString());
      await _loadReview();

      if (mounted) {
        _snack('Row removed.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not remove row: $error');
      }
    }
  }

  Future<void> _publish() async {
    if (_errorRows > 0 || _rows.isEmpty) {
      _snack('Fix or remove all error rows before publishing.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Publish import?',
      message:
          'All $_validRows valid rows will be applied to this branch\'s '
          'live inventory. This cannot be undone.',
      confirmText: 'Publish',
    );

    if (!confirmed) return;

    setState(() => _working = true);

    try {
      await widget.service.publishImport(widget.batchId);
      await _loadReview();

      if (mounted) {
        _snack('Inventory import published successfully.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not publish import: $error');
      }
    }
  }

  Future<void> _discard() async {
    final confirmed = await _confirm(
      title: 'Discard import?',
      message:
          'All staged rows in this batch will be deleted. '
          'Live inventory will not be changed.',
      confirmText: 'Discard',
      danger: true,
    );

    if (!confirmed) return;

    setState(() => _working = true);

    try {
      await widget.service.discardImport(widget.batchId);
      await _loadReview();

      if (mounted) {
        _snack('Import discarded.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not discard import: $error');
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  danger ? AppColors.danger : AppColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Review Import',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _working ? null : _loadReview,
            icon: const Icon(Icons.refresh, color: AppColors.text),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _loadReview,
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final status = _disp(_batch!['status']);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(
          constraints.maxWidth < 700 ? 12 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Import CSV or Excel',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            _ReviewStatus(status: status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Review every row. Edit values, remove rows, '
                          'then publish.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 17),
                        const _ReviewSteps(),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 10,
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 17,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 7),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 260,
                              ),
                              child: Text(
                                _disp(_batch!['file_name']),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _CountChip(
                              label: 'Total',
                              count: _rows.length,
                              tone: _ChipTone.neutral,
                            ),
                            _CountChip(
                              label: 'Valid',
                              count: _validRows,
                              tone: _ChipTone.success,
                            ),
                            _CountChip(
                              label: 'Need fixing',
                              count: _errorRows,
                              tone: _errorRows > 0
                                  ? _ChipTone.danger
                                  : _ChipTone.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isReviewing)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Nothing changes in your inventory until '
                              'you publish.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No rows in this import batch.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    _ImportTable(
                      rows: _rows,
                      isReviewing: _isReviewing,
                      working: _working,
                      rowIsValid: _rowIsValid,
                      messages: _messages,
                      disp: _disp,
                      onEdit: _editRow,
                      onRemove: _removeRow,
                    ),
                  if (_isReviewing)
                    _FooterActionBar(
                      working: _working,
                      canPublish: _errorRows == 0 && _rows.isNotEmpty,
                      errorRows: _errorRows,
                      onDiscard: _discard,
                      onPublish: _publish,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSteps extends StatelessWidget {
  const _ReviewSteps();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StepPillReview(
          number: 1,
          label: 'Upload',
          complete: true,
        ),
        _ReviewConnector(),
        _StepPillReview(
          number: 2,
          label: 'Review and edit',
          active: true,
        ),
        _ReviewConnector(),
        _StepPillReview(
          number: 3,
          label: 'Publish',
        ),
      ],
    );
  }
}

class _StepPillReview extends StatelessWidget {
  const _StepPillReview({
    required this.number,
    required this.label,
    this.active = false,
    this.complete = false,
  });

  final int number;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary
            : complete
                ? AppColors.primaryLight
                : AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$number $label',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active
              ? Colors.white
              : complete
                  ? AppColors.primary
                  : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _ReviewConnector extends StatelessWidget {
  const _ReviewConnector();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        color: AppColors.border,
      ),
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      'reviewing' => ('Reviewing', BadgeTone.warning),
      'published' => ('Published', BadgeTone.success),
      'discarded' => ('Discarded', BadgeTone.neutral),
      _ => (status, BadgeTone.neutral),
    };

    return StatusBadge(label, tone: tone);
  }
}

enum _ChipTone { neutral, success, danger }

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _ChipTone.success => (
          AppColors.primaryLight,
          AppColors.primary,
        ),
      _ChipTone.danger => (
          AppColors.dangerLight,
          AppColors.danger,
        ),
      _ChipTone.neutral => (
          AppColors.neutralLight,
          AppColors.neutral,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _ImportTable extends StatelessWidget {
  const _ImportTable({
    required this.rows,
    required this.isReviewing,
    required this.working,
    required this.rowIsValid,
    required this.messages,
    required this.disp,
    required this.onEdit,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> rows;
  final bool isReviewing;
  final bool working;
  final bool Function(Map<String, dynamic>) rowIsValid;
  final List<String> Function(dynamic) messages;
  final String Function(dynamic) disp;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the available card width. Keep a minimum width on
        // smaller screens so the columns remain readable and scrollable.
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1120.0;

        final tableWidth =
            availableWidth < 1120 ? 1120.0 : availableWidth;

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 15,
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 48, child: _ColHeader('#')),
                        Expanded(
                          flex: 3,
                          child: _ColHeader('Medicine'),
                        ),
                        Expanded(child: _ColHeader('Stock')),
                        Expanded(child: _ColHeader('Price (₱)')),
                        Expanded(child: _ColHeader('Low-stock')),
                        Expanded(
                          flex: 2,
                          child: _ColHeader('Nearest expiry'),
                        ),
                        SizedBox(
                          width: 120,
                          child: _ColHeader('Result'),
                        ),
                        SizedBox(width: 112),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ...rows.map(
                    (row) => _ImportRow(
                      row: row,
                      valid: rowIsValid(row),
                      errors: messages(row['errors']),
                      warnings: messages(row['warnings']),
                      isReviewing: isReviewing,
                      working: working,
                      disp: disp,
                      onEdit: onEdit,
                      onRemove: onRemove,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.row,
    required this.valid,
    required this.errors,
    required this.warnings,
    required this.isReviewing,
    required this.working,
    required this.disp,
    required this.onEdit,
    required this.onRemove,
  });

  final Map<String, dynamic> row;
  final bool valid;
  final List<String> errors;
  final List<String> warnings;
  final bool isReviewing;
  final bool working;
  final String Function(dynamic) disp;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onRemove;

  @override
  Widget build(BuildContext context) {
    final bg = !valid
        ? AppColors.dangerLight.withValues(alpha: 0.35)
        : warnings.isNotEmpty
            ? AppColors.warningLight.withValues(alpha: 0.25)
            : AppColors.surface;

    return Container(
      color: bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${row['source_row_number'] ?? '—'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    disp(row['medicine_label']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    disp(row['stock_quantity']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    disp(row['price_per_unit']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    disp(row['low_stock_threshold']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatExpiry(row['nearest_expiry']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: _ResultPill(valid: valid),
                ),
                SizedBox(
                  width: 112,
                  child: isReviewing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Edit row',
                              onPressed: working
                                  ? null
                                  : () => onEdit(row),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              tooltip: 'Remove row',
                              onPressed: working
                                  ? null
                                  : () => onRemove(row),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.danger,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
          if (errors.isNotEmpty || warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 70,
                right: 22,
                bottom: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...errors.map(
                    (e) => _MessageLine(
                      message: e,
                      warning: false,
                    ),
                  ),
                  ...warnings.map(
                    (w) => _MessageLine(
                      message: w,
                      warning: true,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.valid});

  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: valid
            ? AppColors.primaryLight
            : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        valid ? 'Valid' : 'Fix needed',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: valid ? AppColors.primary : AppColors.danger,
        ),
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({
    required this.message,
    required this.warning,
  });

  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning
                ? Icons.warning_amber_outlined
                : Icons.error_outline,
            size: 14,
            color: warning ? AppColors.warning : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: warning ? AppColors.warning : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatExpiry(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';

  final date = DateTime.tryParse(value.toString());
  if (date == null) return value.toString();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _dateString(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _FooterActionBar extends StatelessWidget {
  const _FooterActionBar({
    required this.working,
    required this.canPublish,
    required this.errorRows,
    required this.onDiscard,
    required this.onPublish,
  });

  final bool working;
  final bool canPublish;
  final int errorRows;
  final VoidCallback onDiscard;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorRows > 0)
                Text(
                  '$errorRows ${errorRows == 1 ? 'row needs' : 'rows need'} '
                  'fixing or removing before you can publish.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Text(
                  'All rows are ready to publish.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: working ? null : onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('Discard import'),
              ),
              const SizedBox(width: 9),
              FilledButton(
                onPressed: working || !canPublish ? null : onPublish,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.neutralLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: working
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: 1,
        maxLines: 1,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.8,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          constraints: const BoxConstraints(
            minHeight: 48,
          ),
          isDense: false,
        ),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.text,
        ),
      ),
    );
  }
}
