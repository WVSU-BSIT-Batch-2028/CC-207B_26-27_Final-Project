// F5 Buyer Requests: the Post / Edit request form, with validation and a
// "Discard changes?" warning.

import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../services/assistant_controller.dart';

import '../models/buyer_request.dart';
import '../services/auth_service.dart';
import '../services/request_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/date_field.dart';
import '../widgets/crop_picker.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/labeled_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_body.dart';

/// Form to post a new request, or edit [request] when it is given.
/// Closes with `true` when something was saved.
class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key, this.request});

  final BuyerRequest? request;

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _targetPriceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _crop;
  String? _unit = 'kg';
  String? _town = AuthService.currentUser?.town;
  DateTime? _neededBy;
  bool _isSaving = false;
  bool _hasChanges = false;

  bool get _isEditing => widget.request != null;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    if (request != null) {
      _crop = request.crop;
      _unit = request.unit;
      _town = request.town;
      _neededBy = request.neededBy;
      _quantityController.text = formatQuantity(request.quantity);
      _targetPriceController.text =
          request.targetPrice?.toStringAsFixed(2) ?? '';
      _notesController.text = request.notes;
    }
    // Old profiles might have a town that is not in our list.
    if (!kTowns.contains(_town)) _town = null;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _targetPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// The target price is optional, but if typed it must be a valid price.
  String? _validateTargetPrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return Validators.price(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final buyer = AuthService.currentUser!;
    final targetText = _targetPriceController.text.trim();
    final request = BuyerRequest(
      id: widget.request?.id ?? '',
      buyerId: buyer.id,
      buyerName: buyer.name,
      crop: _crop!,
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unit!,
      targetPrice: targetText.isEmpty ? null : double.parse(targetText),
      town: _town!,
      neededBy: _neededBy!,
      notes: _notesController.text.trim(),
      createdAt: widget.request?.createdAt ?? DateTime.now(),
      closedByBuyer: widget.request?.closedByBuyer ?? false,
    );
    try {
      await RequestService().save(request);
      if (!mounted) return;
      showMessage(context, _isEditing ? 'Request updated.' : 'Request posted.');
      // Navigator.pop closes the screen even when PopScope says canPop:
      // false. PopScope only stops the back button and back gesture.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A form: the AI assistant's round button hides so it never covers
    // the form's buttons.
    return AssistantScope(
      page: const AssistantPage(AssistantScreen.requests, hideButton: true),
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDiscardChangesDialog(context);
        if (discard && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit request' : 'Post a request'),
        ),
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
                  eyebrow: _isEditing ? 'Edit request' : 'New request',
                  title: 'What do you need?',
                  lead:
                      'Farmers see this in Buyer Demand and can message you '
                      'with offers.',
                ),
                // Editing an expired request: explain what to do.
                if (widget.request?.status == RequestStatus.expired) ...[
                  const SizedBox(height: AppSizes.fieldGap),
                  NoticeBox(
                    kind: NoticeKind.warning,
                    message:
                        'This request expired on '
                        '${formatDate(widget.request!.neededBy)}. Choose a new '
                        '"Needed by" date to show it to farmers again.',
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
                LabeledField(
                  label: 'Quantity',
                  isRequired: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 100',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: Validators.positiveNumber,
                        ),
                      ),
                      const SizedBox(width: AppSizes.small),
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
                  label: 'Target price per ${_unit ?? 'unit'}',
                  help: 'Leave empty if you are open to offers.',
                  child: TextFormField(
                    controller: _targetPriceController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 42.00',
                      prefixText: '₱ ',
                      suffixText: '/${_unit ?? 'unit'}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validateTargetPrice,
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Needed by',
                  isRequired: true,
                  child: DateField(
                    label: null,
                    value: _neededBy,
                    firstDate: DateTime.now(),
                    // An expired request must get a new date to open again.
                    notBeforeToday: true,
                    onChanged: (date) => setState(() {
                      _neededBy = date;
                      _hasChanges = true;
                    }),
                  ),
                ),
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Delivery town',
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
                  label: 'Notes',
                  child: TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. For a carinderia, weekly order',
                    ),
                    maxLines: 3,
                    maxLength: 300,
                    validator: Validators.maxLength(300),
                  ),
                ),
                const SizedBox(height: AppSizes.sectionGap),
                LoadingButton(
                  label: _isEditing ? 'Save changes' : 'Post request',
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
