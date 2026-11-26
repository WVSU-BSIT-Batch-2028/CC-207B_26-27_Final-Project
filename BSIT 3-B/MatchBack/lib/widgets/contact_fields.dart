import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/validators.dart';

/// The contact section used by both the lost report and claim forms.
/// The values are saved in a staff-only collection, never in the public report.
class ContactFields extends StatelessWidget {
  const ContactFields({
    required this.emailController,
    required this.phoneController,
    required this.enabled,
    this.nameController,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController phoneController;
  final bool enabled;

  /// When null, the full name field is hidden (the claim form already has
  /// its own name field).
  final TextEditingController? nameController;

  @override
  Widget build(BuildContext context) {
    final nameField = nameController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Only staff can see these. They are never shown on public '
          'listings. Provide an email address, a phone number, or both.',
        ),
        const SizedBox(height: 16),
        if (nameField != null) ...[
          TextFormField(
            controller: nameField,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
            validator: validateFullName,
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: emailController,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'name@school.edu.ph',
            border: OutlineInputBorder(),
          ),
          // Also checks that at least one of email or phone was given.
          validator: (value) {
            final error = validateEmail(value);
            if (error != null) return error;
            return validateContactMethod(value ?? '', phoneController.text);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: phoneController,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '09171234567',
            border: OutlineInputBorder(),
          ),
          validator: validatePhone,
        ),
      ],
    );
  }
}
