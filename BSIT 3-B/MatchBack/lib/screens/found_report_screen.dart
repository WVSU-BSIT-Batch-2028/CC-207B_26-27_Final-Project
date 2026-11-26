import 'package:flutter/material.dart';

import '../models/found_item.dart';
import '../services/found_item_storage.dart';
import '../services/report_image_storage.dart';
import '../widgets/image_picker_field.dart';

class FoundReportScreen extends StatefulWidget {
  const FoundReportScreen({super.key});

  @override
  State<FoundReportScreen> createState() => _FoundReportScreenState();
}

class _FoundReportScreenState extends State<FoundReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = FoundItemStorage();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateFoundController = TextEditingController();
  final _storageLocationController = TextEditingController();

  String? _selectedCategory;
  bool _isSaving = false;
  ReportImageData? _image;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateFoundController.dispose();
    _storageLocationController.dispose();
    super.dispose();
  }

  String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final report = FoundItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: _selectedCategory!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        locationFound: _locationController.text.trim(),
        dateFound: _dateFoundController.text.trim(),
        storageLocation: _storageLocationController.text.trim(),
        status: 'found',
        hasImage: _image != null,
      );

      await _storage.save(report, image: _image);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Found-item report saved successfully.')),
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
      appBar: AppBar(title: const Text('Report a Found Item')),
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
                    'Tell us about the item you found.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Do not include a student’s name, contact details, or other '
                    'personal information in the public description.',
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
                      hintText: 'Example: Black umbrella',
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
                      labelText: 'Public description',
                      hintText: 'Describe color, brand, or visible details.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final error = requiredField(value, 'Public description');
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
                      labelText: 'Location found',
                      hintText: 'Example: Library, second floor',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        requiredField(value, 'Location found'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dateFoundController,
                    enabled: !_isSaving,
                    readOnly: true,
                    onTap: _isSaving
                        ? null
                        : () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );

                            if (selectedDate != null) {
                              _dateFoundController.text =
                                  '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
                            }
                          },
                    decoration: const InputDecoration(
                      labelText: 'Date found',
                      hintText: 'Select the date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => requiredField(value, 'Date found'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _storageLocationController,
                    maxLength: 100,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Private storage location',
                      hintText: 'Example: Faculty Office cabinet A',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        requiredField(value, 'Private storage location'),
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
                        : const Icon(Icons.add_circle_outline),
                    label: Text(
                      _isSaving
                          ? 'Saving report...'
                          : 'Submit Found-Item Report',
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
