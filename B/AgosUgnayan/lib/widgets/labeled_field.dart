// A form field with its label above it, like the website's forms: a red
// star for required fields, a grey "Optional" tag for the others, and an
// optional help line under the field.

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// [label] above [child] (usually a TextFormField or dropdown).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
    this.help,
  });

  final String label;
  final Widget child;

  /// True adds a red "*"; false adds a grey "Optional" tag.
  final bool isRequired;

  /// Grey line under the field, e.g. the PSA reference price.
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The label is also read by screen readers together with the field.
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                )
              else
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _OptionalTag(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.labelGap),
        child,
        if (help != null) ...[
          const SizedBox(height: 4),
          Text(help!, style: AppTextStyles.meta),
        ],
      ],
    );
  }
}

/// The small grey "Optional" box after a label.
class _OptionalTag extends StatelessWidget {
  const _OptionalTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.segmented,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Optional',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// The "* Required" note at the top of a form.
class RequiredNote extends StatelessWidget {
  const RequiredNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '* ',
            style: TextStyle(color: AppColors.danger),
          ),
          TextSpan(text: 'Required'),
        ],
      ),
      style: AppTextStyles.meta,
    );
  }
}
