
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../services/inventory_import_service.dart';
import '../../../../widgets/theme/app_colors.dart';
import 'inventory_import_review_screen.dart';

// Ph-28: Inventory import upload. Navigation and service behavior are unchanged.
class InventoryImportUploadScreen extends StatefulWidget {
  InventoryImportUploadScreen({super.key, InventoryImportService? service})
      : service = service ?? InventoryImportService();

  final InventoryImportService service;

  @override
  State<InventoryImportUploadScreen> createState() =>
      _InventoryImportUploadScreenState();
}

class _InventoryImportUploadScreenState
    extends State<InventoryImportUploadScreen> {
  static const int _maxFileSize = 2 * 1024 * 1024;

  bool _isDownloading = false;
  bool _isUploading = false;
  String? _selectedFileName;
  String? _errorMessage;

  Future<void> _downloadTemplate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await widget.service.downloadTemplate();

      if (!mounted) return;

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save inventory import template',
        fileName: 'meditech_inventory_template.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;

      _showSnack(
        savedPath == null
            ? 'Template download cancelled.'
            : 'Template saved.',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _selectAndUploadFile() async {
    setState(() => _errorMessage = null);

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (!mounted || file == null) return;

      final extension = file.extension?.toLowerCase();

      if (extension != 'csv' && extension != 'xlsx') {
        setState(() => _errorMessage = 'Please select a CSV or XLSX file.');
        return;
      }

      final fileSize = file.lengthSync() ?? await file.length();

      if (fileSize == null) {
        setState(
          () => _errorMessage =
              'Unable to determine the selected file size.',
        );
        return;
      }

      if (fileSize > _maxFileSize) {
        setState(
          () => _errorMessage = 'The selected file exceeds the 2 MB limit.',
        );
        return;
      }

      if (fileSize == 0) {
        setState(() => _errorMessage = 'The selected file is empty.');
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedFileName = file.name;
        _isUploading = true;
      });

      final response = await widget.service.uploadFile(
        bytes: bytes,
        fileName: file.name,
      );

      if (!mounted) return;

      final batchId = response['batch_id']?.toString();

      if (batchId == null || batchId.isEmpty) {
        throw Exception('The import service did not return a batch ID.');
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InventoryImportReviewScreen(
            batchId: batchId,
            service: widget.service,
          ),
        ),
      );

      if (mounted) {
        setState(() => _selectedFileName = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isDownloading || _isUploading;

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
          'Import Inventory',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 600 ? 16 : 32,
              vertical: constraints.maxWidth < 600 ? 20 : 36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    constraints.maxWidth < 600 ? 18 : 28,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ImportHeader(activeStep: 1),
                      const SizedBox(height: 30),
                      const Text(
                        'Export a stock report from your POS and use the '
                        'MediTech template. You will review every row before '
                        'anything changes in your inventory.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'Template columns: medicine (brand and strength), '
                          'stock_quantity, price_per_unit, '
                          'low_stock_threshold (optional), '
                          'nearest_expiry_date (optional, YYYY-MM-DD)',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _downloadTemplate,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.download_outlined,
                                size: 18,
                              ),
                        label: Text(
                          _isDownloading
                              ? 'Downloading...'
                              : 'Download template (.xlsx)',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _UploadDropZone(
                        fileName: _selectedFileName,
                        uploading: _isUploading,
                        onTap: busy ? null : _selectAndUploadFile,
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'CSV or XLSX · Up to 2 MB · Up to 1,000 rows',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (_isUploading) ...[
                        const SizedBox(height: 18),
                        const LinearProgressIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.primaryLight,
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Processing file. Inventory will not change '
                            'until you publish.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 18),
                        _UploadError(message: _errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImportHeader extends StatelessWidget {
  const _ImportHeader({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Import CSV or Excel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            Icon(
              Icons.upload_file_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Upload a file from your POS export',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _StepPill(
              number: 1,
              label: 'Upload',
              active: activeStep == 1,
            ),
            const _StepConnector(),
            _StepPill(
              number: 2,
              label: 'Review and edit',
              active: activeStep == 2,
            ),
            const _StepConnector(),
            _StepPill(
              number: 3,
              label: 'Publish',
              active: activeStep == 3,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$number $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

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

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({
    required this.fileName,
    required this.uploading,
    required this.onTap,
  });

  final String? fileName;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;

    return Material(
      color: hasFile
          ? AppColors.primaryLight
          : const Color(0xFFF3F8F4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary,
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFile
                    ? Icons.description_outlined
                    : Icons.file_upload_outlined,
                size: 34,
                color: AppColors.primary,
              ),
              const SizedBox(height: 9),
              Text(
                uploading
                    ? 'Uploading and processing...'
                    : hasFile
                        ? fileName!
                        : 'Choose CSV or Excel file',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                hasFile
                    ? 'Tap to choose a different file'
                    : '.csv or .xlsx · up to 2 MB · up to 1,000 rows',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadError extends StatelessWidget {
  const _UploadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
