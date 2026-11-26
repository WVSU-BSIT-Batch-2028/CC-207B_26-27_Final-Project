import 'package:flutter/material.dart';

import '../models/claim_request.dart';
import '../models/contact_details.dart';
import '../utils/validators.dart';
import '../widgets/contact_fields.dart';
import '../models/found_item.dart';
import '../services/auth_service.dart';
import '../services/claim_storage.dart';
import '../services/found_item_storage.dart';

class ClaimScreen extends StatefulWidget {
  const ClaimScreen({this.initialFoundItemId, super.key});

  /// Optional: pre-selects a found item (used when coming from AI Match).
  final String? initialFoundItemId;

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _claimStorage = ClaimStorage();
  final _foundItemStorage = FoundItemStorage();

  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _privateDetailController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  late Future<List<FoundItem>> _foundItemsFuture;
  String? _selectedFoundItemId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _foundItemsFuture = _foundItemStorage.loadAll();
    _selectedFoundItemId = widget.initialFoundItemId;
    _nameController.text = AuthService.current?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _privateDetailController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Loads the found items again after an error (the "Try Again" button).
  void reloadFoundItems() {
    setState(() {
      _foundItemsFuture = _foundItemStorage.loadAll();
    });
  }

  String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  Future<void> submitClaim(List<FoundItem> foundItems) async {
    if (!_formKey.currentState!.validate()) return;

    final selectedItem = foundItems.firstWhere(
      (item) => item.id == _selectedFoundItemId,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      // Stop a student from sending a second claim for the same item while
      // the first one is still being handled.
      if (await _claimStorage.hasOpenClaim(selectedItem.id)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an open claim for this item. '
              'Check My Claims for its status.',
            ),
          ),
        );
        return;
      }

      final claim = ClaimRequest(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        foundItemId: selectedItem.id,
        foundItemName: selectedItem.name,
        claimantName: _nameController.text.trim(),
        reason: _reasonController.text.trim(),
        privateDetail: _privateDetailController.text.trim(),
        status: 'pending',
        submittedAt: DateTime.now().toIso8601String(),
        studentId: AuthService.current?.studentId ?? '',
        ownerUid: AuthService.current?.uid ?? '',
      );

      // The claim form's name field doubles as the required full name.
      final contact = ContactDetails(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: cleanPhone(_phoneController.text),
      );

      await _claimStorage.save(claim, contact: contact);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim submitted for staff verification.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the claim. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoundItem>>(
      future: _foundItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Submit a Claim')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not load found-item reports.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: reloadFoundItems,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        // Only items still waiting to be claimed can be claimed.
        final foundItems = (snapshot.data ?? [])
            .where((item) => item.status == 'found')
            .toList();

        if (foundItems.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Submit a Claim')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'There are no found-item reports available to claim yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Submit a Claim')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request ownership verification',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Claims are reviewed by staff. AI suggestions do not '
                        'automatically prove ownership.',
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue:
                            foundItems.any(
                              (item) => item.id == _selectedFoundItemId,
                            )
                            ? _selectedFoundItemId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Found item',
                          border: OutlineInputBorder(),
                        ),
                        items: foundItems
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  '${item.name} - ${item.locationFound}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedFoundItemId = value;
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Please select an item.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 80,
                        enabled: !_isSaving,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => validateFullName(value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonController,
                        maxLength: 500,
                        enabled: !_isSaving,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Why do you believe this is your item?',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final error = requiredField(value, 'Explanation');
                          if (error != null) return error;
                          if (value!.trim().length < 10) {
                            return 'Use at least 10 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _privateDetailController,
                        maxLength: 500,
                        enabled: !_isSaving,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Private identifying detail',
                          hintText: 'A detail not shown in the public report',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            requiredField(value, 'Private identifying detail'),
                      ),
                      const SizedBox(height: 24),
                      ContactFields(
                        emailController: _emailController,
                        phoneController: _phoneController,
                        enabled: !_isSaving,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => submitClaim(foundItems),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(
                          _isSaving ? 'Submitting claim...' : 'Submit Claim',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
