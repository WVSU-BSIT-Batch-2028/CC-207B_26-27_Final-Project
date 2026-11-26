import 'package:flutter/material.dart';

import '../models/contact_details.dart';
import '../models/lost_item.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/contact_fields.dart';
import '../services/lost_item_storage.dart';
import '../services/report_image_storage.dart';
import '../widgets/image_picker_field.dart';

class LostReportScreen extends StatefulWidget {
  const LostReportScreen({super.key});

  @override
  State<LostReportScreen> createState() => _LostReportScreenState();
}

class _LostReportScreenState extends State<LostReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = LostItemStorage();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateLostController = TextEditingController();
  final _privateDetailController = TextEditingController();
  // Prefilled with the name entered at login, if there was one.
  final _contactNameController = TextEditingController(
    text: AuthService.current?.name ?? '',
  );
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedCategory;
  bool _isSaving = false;
  ReportImageData? _image;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateLostController.dispose();
    _privateDetailController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  Future<void> selectDate(TextEditingController controller) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      controller.text =
          '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
    }
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final report = LostItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: _selectedCategory!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        dateLost: _dateLostController.text.trim(),
        privateDetail: _privateDetailController.text.trim(),
        status: 'lost',
        hasImage: _image != null,
      );

      final contact = ContactDetails(
        fullName: _contactNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: cleanPhone(_phoneController.text),
      );

      await _storage.save(report, contact: contact, image: _image);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lost-item report saved successfully.')),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the report. Please try again.'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Lost Item')),
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
                    'Tell us about the item you lost.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Do not include your phone number, student ID, or other '
                    'personal details in the description. Add your contact '
                    'details in the section below instead.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Item category',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const [
                              'Bag',
                              'Bottle',
                              'Clothing',
                              'Electronics',
                              'School supply',
                              'Other',
                            ]
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                    validator: (value) =>
                        value == null ? 'Please select a category.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    maxLength: 100,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      hintText: 'Example: Blue water bottle',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => requiredField(value, 'Item name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 500,
                    enabled: !_isSaving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Describe its color, brand, or visible details.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final error = requiredField(value, 'Description');
                      if (error != null) return error;
                      if (value!.trim().length < 10) {
                        return 'Use at least 10 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    maxLength: 100,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Last known location',
                      hintText: 'Example: Library, second floor',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        requiredField(value, 'Last known location'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dateLostController,
                    enabled: !_isSaving,
                    readOnly: true,
                    onTap: _isSaving
                        ? null
                        : () {
                            selectDate(_dateLostController);
                          },
                    decoration: const InputDecoration(
                      labelText: 'Date lost',
                      hintText: 'Select the date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => requiredField(value, 'Date lost'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _privateDetailController,
                    maxLength: 500,
                    enabled: !_isSaving,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Private identifying detail',
                      hintText: 'Only staff should use this to verify a claim.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        requiredField(value, 'Private identifying detail'),
                  ),
                  const SizedBox(height: 24),
                  ContactFields(
                    nameController: _contactNameController,
                    emailController: _emailController,
                    phoneController: _phoneController,
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: 24),
                  ImagePickerField(
                    label: 'Photo of the item (optional)',
                    image: _image,
                    enabled: !_isSaving,
                    onChanged: (image) {
                      setState(() {
                        _image = image;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : submitReport,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSaving
                          ? 'Saving report...'
                          : 'Submit Lost-Item Report',
                    ),
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
