// The buyer's "Request to buy" form for one listing: how much (more than 0
// and at most what is available), an optional note, and the total worked
// out as they type. Sending it creates a pending order and an order card in
// the chat. Nothing is held until the farmer accepts.

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../utils/app_exception.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import 'labeled_field.dart';
import 'loading_button.dart';

/// Opens the form for [listing]. Returns true when a request was sent.
Future<bool> showRequestToBuySheet(BuildContext context, Listing listing) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true, // lets the sheet move up above the keyboard
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _RequestToBuyForm(listing: listing),
  ).then((sent) => sent ?? false);
}

class _RequestToBuyForm extends StatefulWidget {
  const _RequestToBuyForm({required this.listing});

  final Listing listing;

  @override
  State<_RequestToBuyForm> createState() => _RequestToBuyFormState();
}

class _RequestToBuyFormState extends State<_RequestToBuyForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSending = false;

  Listing get _listing => widget.listing;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _qty => double.tryParse(_qtyController.text.trim());

  /// More than 0 and at most what buyers can still ask for.
  String? _qtyValidator(String? value) {
    final problem = Validators.positiveNumber(value);
    if (problem != null) return problem;
    final available = _listing.available;
    if (double.parse(value!.trim()) > available) {
      return 'Only ${formatQuantity(available)} ${_listing.unit} is '
          'available. Enter that or less.';
    }
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    final me = AuthService.currentUser!;
    try {
      await OrderService().requestToBuy(
        listing: _listing,
        qty: _qty!,
        note: _noteController.text.trim(),
        buyerId: me.id,
        buyerName: me.name,
      );
      if (!mounted) return;
      showMessage(
        context,
        'Request sent to ${_listing.farmerName}. Nothing is held for you '
        'until the farmer accepts. See it in My orders.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = _qty;
    final unit = _listing.unit;
    return Padding(
      // Keeps the form above the phone's keyboard.
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        0,
        AppSizes.pagePadding,
        MediaQuery.viewInsetsOf(context).bottom + AppSizes.pagePadding,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Request to buy ${_listing.crop}',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatQuantity(_listing.available)} $unit available at '
                '${formatPeso(_listing.price)}/$unit from '
                '${_listing.farmerName}.',
                style: AppTextStyles.meta,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LabeledField(
                label: 'How much do you want?',
                isRequired: true,
                child: TextFormField(
                  controller: _qtyController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. 5',
                    suffixText: unit,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _qtyValidator,
                  onChanged: (_) => setState(() {}), // updates the total
                ),
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LabeledField(
                label: 'Note to the farmer',
                child: TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. I can pick it up on Saturday morning',
                  ),
                  maxLength: 200,
                  validator: Validators.maxLength(200),
                ),
              ),
              Text(
                qty == null || qty <= 0
                    ? 'Total: enter how much first'
                    : 'Total: ${formatPeso(orderTotal(qty, _listing.price))}',
                style: AppTextStyles.price,
              ),
              const SizedBox(height: 4),
              const Text(
                'The farmer must accept before anything is held for you. '
                'You can agree on pickup and payment in the chat.',
                style: AppTextStyles.meta,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LoadingButton(
                label: 'Send request',
                isLoading: _isSending,
                onPressed: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
