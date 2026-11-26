// F1 Crop Listings: the Add / Edit crop form. It has validation on every
// field, a reference price hint, a "Discard changes?" warning, and the
// F3 AI Listing Assistant box at the top.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/ai_listing_suggestion.dart';
import '../models/listing.dart';
import '../models/price_record.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/listing_photo_service.dart';
import '../services/listing_service.dart';
import '../services/price_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/ai_assistant_box.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/date_field.dart';
import '../widgets/crop_picker.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/labeled_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/photo_picker_field.dart';
import '../widgets/responsive_body.dart';

/// Form to add a new crop listing, or edit [listing] when it is given.
/// Closes with `true` when something was saved.
class CropFormScreen extends StatefulWidget {
  const CropFormScreen({super.key, this.listing});

  final Listing? listing; // null = add a new crop

  @override
  State<CropFormScreen> createState() => _CropFormScreenState();
}

class _CropFormScreenState extends State<CropFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  String? _crop;
  String? _unit = 'kg';
  String? _town; // where the crop is; starts as the farmer's own town
  DateTime? _harvestDate = DateTime.now(); // starts as today, like the website
  bool _isSaving = false;
  bool _hasChanges = false; // for the "Discard changes?" warning
  bool _aiUsed = false; // true once the AI filled in the form
  bool _isDescribing = false; // waiting for the AI description
  bool _descriptionByAi = false; // shows the AI-generated label there
  String? _describeError; // shown under the button when the AI fails
  List<PriceRecord> _prices = []; // for the reference price hint
  Uint8List? _photo; // the farmer's own photo, already shrunk
  bool _photoChanged = false; // added, changed or removed in this form

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    if (listing != null) {
      _crop = listing.crop;
      _unit = listing.unit;
      _quantityController.text = formatQuantity(listing.quantity);
      _priceController.text = listing.price.toStringAsFixed(2);
      _descriptionController.text = listing.description;
      _titleController.text = listing.title;
      _harvestDate = listing.harvestDate;
      // Only a town from our list, or the dropdown would not know it.
      _town = kTowns.contains(listing.town) ? listing.town : null;
      _aiUsed = listing.aiAssisted;
    }
    final myTown = AuthService.currentUser?.town;
    _town ??= kTowns.contains(myTown) ? myTown : null;
    _loadPrices();
    if (listing?.photoId != null) _loadPhoto(listing!.id);
  }

  /// Shows the photo this listing already has in the preview.
  Future<void> _loadPhoto(String id) async {
    final photo = await ListingPhotoService.instance.photoFor(id);
    if (mounted && !_photoChanged) setState(() => _photo = photo);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Loads reference prices for the hint. If it fails we just show no hint.
  Future<void> _loadPrices() async {
    try {
      final data = await PriceService().fetchRecent();
      if (mounted) setState(() => _prices = data.records);
    } catch (_) {}
  }

  /// Puts the AI's suggestion into the form. Fields the AI left empty keep
  /// what the farmer already typed. Everything stays editable.
  void _applySuggestion(AiListingSuggestion suggestion) {
    setState(() {
      _crop = suggestion.crop ?? _crop;
      _unit = suggestion.unit ?? _unit;
      if (suggestion.quantity != null) {
        _quantityController.text = formatQuantity(suggestion.quantity!);
      }
      if (suggestion.price != null) {
        _priceController.text = suggestion.price!.toStringAsFixed(2);
      }
      if (suggestion.description != null) {
        _descriptionController.text = suggestion.description!;
      }
      _aiUsed = true;
      _hasChanges = true;
    });
    showMessage(
      context,
      'AI filled in the form. Check every field before saving.',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final farmer = AuthService.currentUser!;
    final listing = Listing(
      id: widget.listing?.id ?? '',
      farmerId: farmer.id,
      farmerName: farmer.name,
      crop: _crop!,
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unit!,
      price: double.parse(_priceController.text.trim()),
      town: _town!,
      harvestDate: _harvestDate,
      description: _descriptionController.text.trim(),
      aiAssisted: _aiUsed,
      createdAt: widget.listing?.createdAt ?? DateTime.now(),
      // Editing keeps the status (e.g. a sold-out crop stays sold out).
      status: widget.listing?.status ?? ListingStatus.active,
      title: _titleController.text.trim(),
      hasPhoto: widget.listing?.hasPhoto ?? false,
    );
    try {
      await ListingService().save(
        listing,
        newPhoto: _photoChanged ? _photo : null,
        removePhoto: _photoChanged && _photo == null,
      );
      if (!mounted) return;
      showMessage(
        context,
        _isEditing
            ? 'Changes saved.'
            : '${listing.headline} posted. Buyers can now see it.',
      );
      // Navigator.pop closes the screen even when PopScope says canPop:
      // false. PopScope only stops the back button and back gesture.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showError(context, friendlyMessage(e));
    }
  }

  /// The PSA reference price under the price field (website wording).
  String _priceHint() {
    if (_crop == null) {
      return 'Choose a crop to see the latest PSA farmgate price.';
    }
    final latest = PriceService.latestFor(_crop!, _prices);
    if (latest == null) return 'PSA has no farmgate price for this crop yet.';
    final older = PriceService.isOlderPrice(_crop!, _prices)
        ? ', an older price'
        : '';
    return 'For reference: PSA farmgate average, Iloilo Province, is '
        '${formatPeso(latest.price)}/kg (${formatMonthKey(latest.month)}$older).';
  }

  /// Asks the AI for a short description of the chosen crop. If the
  /// farmer already wrote something, asks before replacing it.
  Future<void> _generateDescription() async {
    final crop = _crop;
    if (crop == null) return;
    setState(() {
      _isDescribing = true;
      _describeError = null;
    });
    try {
      final text = await AiService().describeCrop(crop);
      if (!mounted) return;
      final hasOwnText = _descriptionController.text.trim().isNotEmpty;
      final replace =
          !hasOwnText ||
          await showConfirmDialog(
            context,
            title: 'Replace your description?',
            message: 'The AI wrote: "$text"',
            confirmLabel: 'Replace',
            cancelLabel: 'Keep mine',
            isDestructive: false,
          );
      if (!mounted || !replace) return;
      setState(() {
        _descriptionController.text = text;
        _descriptionByAi = true;
        _aiUsed = true;
        _hasChanges = true;
      });
      showMessage(context, 'AI wrote a description. Check and edit it.');
    } catch (e) {
      if (mounted) setState(() => _describeError = friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isDescribing = false);
    }
  }

  /// Under the quantity when editing: how the total is used now.
  String? _stockHelp() {
    final listing = widget.listing;
    if (listing == null) return null;
    final unit = listing.unit;
    return 'Sold ${formatQuantity(listing.soldQty)} $unit · reserved '
        '${formatQuantity(listing.reserved)} $unit · available '
        '${formatQuantity(listing.available)} $unit. Buyers see the '
        'available amount.';
  }

  /// Required, a number above 0, and at most 100,000 (like the website).
  String? _quantityValidator(String? value) {
    final problem = Validators.positiveNumber(value);
    if (problem != null) return problem;
    final quantity = double.parse(value!.trim());
    if (quantity > 100000) {
      return 'Enter a quantity up to 100,000.';
    }
    // The total can't go below what is already sold or held for buyers.
    final listing = widget.listing;
    if (listing != null) {
      final used = listing.soldQty + listing.reserved;
      if (quantity < used) {
        return 'You already sold or reserved ${formatQuantity(used)} '
            '${listing.unit}. Enter at least that.';
      }
    }
    return null;
  }

  /// Required, a price above 0 and below ₱10,000 (like the website).
  String? _priceValidator(String? value) {
    final problem = Validators.price(value);
    if (problem != null) return problem;
    if (double.parse(value!.trim()) >= 10000) {
      return 'Price must be below ₱10,000, like 54.50.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // PopScope asks "Discard changes?" before leaving with unsaved edits.
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDiscardChangesDialog(context);
        if (discard && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit crop' : 'Add a crop')),
        body: Form(
          key: _formKey,
          // setState so PopScope knows there are unsaved changes now.
          onChanged: () {
            if (!_hasChanges) setState(() => _hasChanges = true);
          },
          child: ResponsiveBody(
            maxWidth: AppSizes.maxFormWidth,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              children: [
                PageHeader(
                  eyebrow: _isEditing ? 'Update your listing' : 'New listing',
                  title: _isEditing ? 'Edit crop' : 'Add a crop',
                ),
                const SizedBox(height: AppSizes.sectionGap),
                if (!_isEditing) AiAssistantBox(onSuggestion: _applySuggestion),
                if (_aiUsed) ...[
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AiGeneratedChip(),
                  ),
                ],
                const SizedBox(height: AppSizes.sectionGap),
                const RequiredNote(),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Crop',
                  isRequired: true,
                  // 71 crops: a searchable list grouped by category.
                  child: CropPickerField(
                    value: _crop,
                    onChanged: (value) => setState(() => _crop = value),
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                // Optional name buyers will recognise, e.g. a stall name.
                // The crop above stays the real crop for search and filters.
                LabeledField(
                  label: 'Listing title or stall name',
                  help:
                      'Leave empty to show only the crop name. The crop '
                      'name is always shown too.',
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: "e.g. Juan's Food Stall",
                    ),
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.maxLength(40),
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: _isEditing ? 'Total stock' : 'Quantity',
                  isRequired: true,
                  help: _stockHelp(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 180',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _quantityValidator,
                        ),
                      ),
                      const SizedBox(width: AppSizes.small),
                      // Our app also sells by sack, bundle or piece.
                      Expanded(
                        flex: 2,
                        child: DropdownField(
                          label: null,
                          items: kUnits,
                          value: _unit,
                          onChanged: (value) => setState(() => _unit = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Asking price per ${_unit ?? 'unit'}',
                  isRequired: true,
                  help: _priceHint(),
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 54.50',
                      prefixText: '₱ ',
                      suffixText: '/${_unit ?? 'unit'}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _priceValidator,
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Town',
                  isRequired: true,
                  child: DropdownField(
                    label: null,
                    items: kTowns,
                    value: _town,
                    onChanged: (value) => setState(() => _town = value),
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Harvest date',
                  isRequired: true,
                  child: DateField(
                    label: null,
                    value: _harvestDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    onChanged: (date) => setState(() {
                      _harvestDate = date;
                      _hasChanges = true;
                    }),
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Description',
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Firm, ripe tomatoes sorted by size',
                    ),
                    maxLines: 3,
                    maxLength: 500,
                    validator: Validators.maxLength(500),
                  ),
                ),
                // Optional: the AI writes a short description of the crop.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: _crop == null
                        ? 'Choose a crop first'
                        : 'The AI writes a short description you can edit',
                    child: OutlinedButton.icon(
                      onPressed: _crop == null || _isDescribing
                          ? null
                          : _generateDescription,
                      icon: _isDescribing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _isDescribing
                            ? 'Writing a description…'
                            : 'Generate crop description',
                      ),
                    ),
                  ),
                ),
                if (_descriptionByAi) ...[
                  const SizedBox(height: AppSizes.small),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AiGeneratedChip(),
                  ),
                ],
                if (_describeError != null) ...[
                  const SizedBox(height: AppSizes.small),
                  NoticeBox(message: _describeError!, kind: NoticeKind.error),
                ],
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Photo',
                  help: _photo == null
                      ? 'Without your own photo, buyers see a sample photo '
                            'of the crop.'
                      : 'Buyers will see your photo.',
                  child: PhotoPickerField(
                    crop: _crop,
                    photo: _photo,
                    onChanged: (photo) => setState(() {
                      _photo = photo;
                      _photoChanged = true;
                      _hasChanges = true;
                    }),
                  ),
                ),
                const SizedBox(height: AppSizes.sectionGap),
                // Main button, then Cancel (which asks first if something
                // was changed), like the website.
                LoadingButton(
                  label: _isEditing ? 'Save changes' : 'Post crop',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
                const SizedBox(height: AppSizes.small),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text(AppStrings.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
