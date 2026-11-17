import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/validators.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'hours_editor.dart';
import 'location_section.dart';
import 'registration_draft.dart';

// Step 1: pharmacy details, opening hours, and store location (wireframe Ph-02 to Ph-04)
class StepPharmacy extends StatelessWidget {
  const StepPharmacy({super.key, required this.draft, required this.errors});

  final RegistrationDraft draft;
  final Map<String, String> errors; // problems the server found

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final e = errors;
    const gap = SizedBox(height: AppSpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tell us about your pharmacy',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'One application per branch. Use the details printed on your License to Operate.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Names
        AppTextField(
          label: 'Pharmacy name',
          hint: 'Enter registered pharmacy name',
          controller: d.pharmacyName,
          errorText: e['pharmacy_name'],
          validator: (v) => Validators.required(v),
        ),
        gap,
        AppTextField(
          label: 'Branch name',
          hint: 'e.g., Main Branch, La Paz Branch',
          controller: d.branchName,
          errorText: e['branch_name'],
          validator: (v) => Validators.required(v),
        ),
        gap,
        AppTextField(
          label: 'Address (as written on your LTO)',
          hint: 'Enter the registered branch address',
          controller: d.address,
          errorText: e['address'],
          validator: (v) => Validators.required(v),
        ),
        gap,

        // Contact details
        AppTextField(
          label: 'Contact number',
          hint: '033-XXX-XXXX or 09-XXXXXXXXX',
          controller: d.contactNumber,
          errorText: e['contact_number'],
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: Validators.contactNumber,
        ),
        gap,
        AppTextField(
          label: 'Pharmacy email',
          hint: 'branch@example.com',
          controller: d.pharmacyEmail,
          errorText: e['pharmacy_email'],
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Weekly operating schedule
        HoursEditor(draft: d, serverError: e['hours']),
        const SizedBox(height: AppSpacing.lg),

        // Store location with an inline map
        LocationSection(draft: d, serverError: e['location']),
      ],
    );
  }
}