// The farmer's "Send an offer" form inside a chat: crop, quantity, price
// (with the PSA price as a hint) and the total, an optional note, and an
// optional "Take from my listing". It never creates a Market listing: a
// private offer is only seen by this buyer. Taking it from a listing holds
// that stock at once, so the same kilos can't be sold twice.

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../models/order.dart';
import '../models/price_record.dart';
import '../services/auth_service.dart';
import '../services/listing_service.dart';
import '../services/order_service.dart';
import '../services/price_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import 'crop_picker.dart';
import 'dropdown_field.dart';
import 'labeled_field.dart';
import 'loading_button.dart';

/// Opens the offer form for the chat [chatId] with the buyer [buyerId].
/// Returns true when an offer was sent.
Future<bool> showOfferSheet(
  BuildContext context, {
  required String chatId,
  required String buyerId,
  required String buyerName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) =>
        _OfferForm(chatId: chatId, buyerId: buyerId, buyerName: buyerName),
  ).then((sent) => sent ?? false);
}

class _OfferForm extends StatefulWidget {
  const _OfferForm({
    required this.chatId,
    required this.buyerId,
    required this.buyerName,
  });

  final String chatId;
  final String buyerId;
  final String buyerName;

  @override
  State<_OfferForm> createState() => _OfferFormState();
}

/// The "Take from" choice that means: not from any listing.
const String _noListing = 'Not from a listing (private offer only)';

class _OfferFormState extends State<_OfferForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  final _me = AuthService.currentUser!;
  String? _crop;
  String? _unit = 'kg';
  List<Listing> _myListings = []; // for "Take from my listing"
  List<PriceRecord> _prices = []; // for the PSA price hint
  Listing? _from; // null = private offer with no listing
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadHelpers();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Loads my listings and the PSA prices. If either fails, the form still
  /// works (just without that hint or choice).
  Future<void> _loadHelpers() async {
    try {
      final listings = await ListingService().fetchByFarmer(_me.id);
      if (mounted) setState(() => _myListings = listings);
    } catch (_) {}
    try {
      final data = await PriceService().fetchRecent();
      if (mounted) setState(() => _prices = data.records);
    } catch (_) {}
  }

  /// My listings of the chosen crop that still have stock to offer.
  List<Listing> get _matching => _myListings
      .where((l) => l.crop == _crop && l.isActive && l.available > 0)
      .toList();

  String _label(Listing l) =>
      '${l.headline}: ${formatQuantity(l.available)} ${l.unit} available';

  /// Picking a listing also fills in its unit and price (still editable).
  void _pickFrom(String? label) {
    final listing = _matching.where((l) => _label(l) == label).firstOrNull;
    setState(() {
      _from = listing;
      if (listing != null) {
        _unit = listing.unit;
        if (_priceController.text.trim().isEmpty) {
          _priceController.text = listing.price.toStringAsFixed(2);
        }
      }
    });
  }

  String? _qtyValidator(String? value) {
    final problem = Validators.positiveNumber(value);
    if (problem != null) return problem;
    final from = _from;
    if (from != null && double.parse(value!.trim()) > from.available) {
      return 'That listing has ${formatQuantity(from.available)} '
          '${from.unit} available. Enter that or less.';
    }
    return null;
  }

  String _priceHint() {
    final crop = _crop;
    if (crop == null) return 'Choose a crop to see the PSA farmgate price.';
    final latest = PriceService.latestFor(crop, _prices);
    if (latest == null) return 'PSA has no farmgate price for this crop yet.';
    return 'For reference: PSA farmgate average is '
        '${formatPeso(latest.price)}/kg (${formatMonthKey(latest.month)}).';
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    try {
      await OrderService().sendOffer(
        chatId: widget.chatId,
        farmerId: _me.id,
        farmerName: _me.name,
        buyerId: widget.buyerId,
        buyerName: widget.buyerName,
        crop: _crop!,
        unit: _unit!,
        qty: double.parse(_qtyController.text.trim()),
        price: double.parse(_priceController.text.trim()),
        note: _noteController.text.trim(),
        fromListing: _from,
      );
      if (!mounted) return;
      showMessage(
        context,
        _from == null
            ? 'Offer sent to ${widget.buyerName}. It is not shown in the '
                  'Market.'
            : 'Offer sent. The amount is held on your listing until the '
                  'buyer answers.',
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
    final qty = double.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final matching = _matching;
    return Padding(
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
                'Send an offer to ${widget.buyerName}',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: 4),
              const Text(
                'Only this buyer sees it. It is not posted in the Market.',
                style: AppTextStyles.meta,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LabeledField(
                label: 'Crop',
                isRequired: true,
                child: CropPickerField(
                  value: _crop,
                  onChanged: (crop) => setState(() {
                    _crop = crop;
                    _from = null; // listings depend on the crop
                  }),
                ),
              ),
              if (matching.isNotEmpty) ...[
                const SizedBox(height: AppSizes.fieldGap),
                LabeledField(
                  label: 'Take from my listing',
                  help:
                      'Choose your listing if these kilos are part of it, so '
                      'they are not offered twice.',
                  child: DropdownField(
                    label: null,
                    items: [_noListing, for (final l in matching) _label(l)],
                    value: _from == null ? _noListing : _label(_from!),
                    onChanged: _pickFrom,
                  ),
                ),
              ],
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
                        controller: _qtyController,
                        decoration: const InputDecoration(hintText: 'e.g. 5'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _qtyValidator,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSizes.small),
                    Expanded(
                      flex: 2,
                      // A listing's unit can't change, so it is fixed then.
                      child: _from != null
                          ? InputDecorator(
                              decoration: const InputDecoration(),
                              child: Text(_unit ?? 'kg'),
                            )
                          : DropdownField(
                              label: null,
                              items: kUnits,
                              value: _unit,
                              onChanged: (unit) => setState(() => _unit = unit),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LabeledField(
                label: 'Price per ${_unit ?? 'unit'}',
                isRequired: true,
                help: _priceHint(),
                child: TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 45.00',
                    prefixText: '₱ ',
                    suffixText: '/${_unit ?? 'unit'}',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: Validators.price,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LabeledField(
                label: 'Note',
                child: TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ready for pickup on Friday',
                  ),
                  maxLength: 200,
                  validator: Validators.maxLength(200),
                ),
              ),
              Text(
                qty == null || price == null || qty <= 0 || price <= 0
                    ? 'Total: enter quantity and price'
                    : 'Total: ${formatPeso(orderTotal(qty, price))}',
                style: AppTextStyles.price,
              ),
              const SizedBox(height: 4),
              Text(
                _from == null
                    ? 'The buyer can accept or decline. Offers expire after '
                          '3 days.'
                    : 'The amount is held on your listing now. If the buyer '
                          'declines or does not answer in 3 days, it is '
                          'freed again.',
                style: AppTextStyles.meta,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              LoadingButton(
                label: 'Send offer',
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
