import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../services/drug_info_service.dart';
import 'prescription_info_card.dart';
import 'state_views.dart';

/// "About this medicine": reference text from the US FDA drug label, with a
/// loading skeleton, an empty message and an error with retry.
/// Always labelled as reference only (openFDA's own disclaimer).
class DrugInfoCard extends StatefulWidget {
  const DrugInfoCard({super.key, required this.medicineName});

  /// The medicine to look up, e.g. "Amoxicillin".
  final String medicineName;

  @override
  State<DrugInfoCard> createState() => _DrugInfoCardState();
}

enum _LoadStatus { loading, ready, error }

class _DrugInfoCardState extends State<DrugInfoCard> {
  _LoadStatus _status = _LoadStatus.loading;
  DrugInfo? _info;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final info = await DrugInfoService.instance.fetch(widget.medicineName);
      if (!mounted) return;
      setState(() {
        _info = info;
        _status = _LoadStatus.ready;
      });
    } on DrugInfoException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  Widget _body() {
    final muted = TextStyle(color: AppColors.textMuted, fontSize: 14);
    final text = TextStyle(color: AppColors.textPrimary, fontSize: 14);
    final label = TextStyle(
      color: AppColors.navy,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    switch (_status) {
      case _LoadStatus.loading:
        return const SkeletonBox(height: 64, radius: AppRadius.sm);

      case _LoadStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error, style: muted),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        );

      case _LoadStatus.ready:
        final info = _info;
        if (info == null) {
          return Text(
            'No reference information was found for this medicine.',
            style: muted,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.uses != null) ...[
              Text('Used for', style: label),
              const SizedBox(height: AppSpacing.xs),
              Text(info.uses!, style: text),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (info.warnings != null) ...[
              Text('Warnings', style: label),
              const SizedBox(height: AppSpacing.xs),
              Text(info.warnings!, style: text),
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrescriptionInfoCard(
      icon: Icons.menu_book_outlined,
      children: [
        Text(
          'About this medicine',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _body(),
        const SizedBox(height: AppSpacing.sm),
        // openFDA asks not to rely on it for medical care decisions.
        Text(
          "Reference only, from the US FDA drug label. Not medical advice. Follow your doctor's instructions.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ],
    );
  }
}