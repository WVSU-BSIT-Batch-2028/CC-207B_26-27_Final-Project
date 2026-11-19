import 'package:flutter/material.dart';
import 'package:websupark/screens/driver/renewal_common.dart';
import 'package:websupark/theme/app_colors.dart';

/// The details a driver is allowed to change.
/// The edit screen hands a new VehicleDetails back to the Vehicle screen.
class VehicleDetails {
  const VehicleDetails({
    required this.name,
    required this.mobile,
    required this.color,
    required this.type,
  });

  final String name;
  final String mobile;
  final String color; // e.g. White
  final String type; // e.g. Toyota Vios
}

/// Edit Vehicle: change the driver's own details.
/// NOTE: this screen is NOT in the prototype. Get the team's OK before
/// committing it. It is opened with a plain MaterialPageRoute from the
/// Vehicle screen, so no shared routing file had to change.
class EditVehicleScreen extends StatefulWidget {
  const EditVehicleScreen({
    super.key,
    required this.initial,
    required this.lockedRows,
  });

  /// The current values, shown in the fields when the screen opens.
  final VehicleDetails initial;

  /// Details only the Parking Services Office can change (plate, pass...).
  final List<RenewalRow> lockedRows;

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _colorController;
  late final TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    // Start every field with the current value.
    _nameController = TextEditingController(text: widget.initial.name);
    _mobileController = TextEditingController(text: widget.initial.mobile);
    _colorController = TextEditingController(text: widget.initial.color);
    _typeController = TextEditingController(text: widget.initial.type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _colorController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  // --- Validation: each returns an error message, or null when the value is OK.
  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validateMobile(String? value) {
    // Ignore spaces and dashes, then accept +639XXXXXXXXX or 09XXXXXXXXX.
    final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    final valid = RegExp(r'^(\+63|0)9\d{9}$').hasMatch(digits);
    return valid ? null : 'Enter a valid mobile number, e.g. +63 917 555 0148.';
  }

  void _save() {
    // validate() runs every validator and shows the error messages.
    if (!_formKey.currentState!.validate()) return;

    // Closing the screen with a value hands it back to the Vehicle screen.
    Navigator.pop(
      context,
      VehicleDetails(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        color: _colorController.text.trim(),
        type: _typeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // RenewalScaffold is reused only for its header with a back button.
    return RenewalScaffold(
      title: 'Edit Vehicle',
      subtitle: 'Update your registration details',
      icon: Icons.edit_outlined,
      children: [
        const RenewalHeading(
          title: 'Your details',
          subtitle: 'Change what is outdated, then save.',
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              _LabeledField(
                label: 'Name',
                controller: _nameController,
                validator: (v) => _required(v, 'Please enter your name.'),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Mobile number',
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                hint: '+63 917 555 0148',
                validator: _validateMobile,
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Vehicle color',
                controller: _colorController,
                validator: (v) => _required(v, 'Please enter the vehicle color.'),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Vehicle type',
                controller: _typeController,
                hint: 'e.g. Toyota Vios',
                validator: (v) => _required(v, 'Please enter the vehicle type.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Cannot be changed here',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        RenewalRowsCard(rows: widget.lockedRows),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'To change your plate number or pass details, visit the Parking Services Office.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _save,
            child: const Text('Save changes'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

/// Small gray label above a text field.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
