// F6 Reference Prices, admin side: enter one crop's PSA farmgate price for
// one month. Saving the same crop and month again replaces the old price.

import 'package:flutter/material.dart';

import '../models/price_record.dart';
import '../services/auth_service.dart';
import '../services/price_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/crop_picker.dart';
import '../widgets/labeled_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_body.dart';

/// Admin form for one monthly reference price.
class AdminPriceFormScreen extends StatefulWidget {
  const AdminPriceFormScreen({super.key});

  @override
  State<AdminPriceFormScreen> createState() => _AdminPriceFormScreenState();
}

class _AdminPriceFormScreenState extends State<AdminPriceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  String? _crop;
  String? _month;
  bool _isSaving = false;

  /// The last 12 months as keys, newest first: "2026-11", "2026-10", …
  final List<String> _months = [
    for (var i = 0; i < 12; i++)
      monthKeyOf(DateTime(DateTime.now().year, DateTime.now().month - i)),
  ];

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final record = PriceRecord(
      crop: _crop!,
      month: _month!,
      price: double.parse(_priceController.text.trim()),
    );
    try {
      await PriceService().save(record, AuthService.currentUser!.id);
      if (!mounted) return;
      showMessage(
        context,
        'Price saved for $_crop, ${formatMonthKey(_month!)}.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add price')),
      body: Form(
        key: _formKey,
        child: ResponsiveBody(
          maxWidth: AppSizes.maxFormWidth,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const PageHeader(
                eyebrow: 'Admin',
                title: 'Add a price',
                lead:
                    'Copy the farmgate price per kg from $kPriceSource '
                    '(PSA OpenSTAT).',
              ),
              const SizedBox(height: AppSizes.sectionGap),
              LabeledField(
                label: 'Crop',
                isRequired: true,
                child: CropPickerField(
                  value: _crop,
                  onChanged: (value) => setState(() => _crop = value),
                ),
              ),
              const SizedBox(height: AppSizes.fieldGap),
              // Shows "Nov 2026" but saves "2026-11".
              DropdownButtonFormField<String>(
                initialValue: _month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  for (final month in _months)
                    DropdownMenuItem(
                      value: month,
                      child: Text(formatMonthKey(month)),
                    ),
                ],
                onChanged: (value) => setState(() => _month = value),
                validator: (value) =>
                    value == null ? 'Please choose a month.' : null,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per kg',
                  prefixText: '₱ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: Validators.price,
              ),
              const SizedBox(height: AppSizes.sectionGap),
              LoadingButton(
                label: 'Save price',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
