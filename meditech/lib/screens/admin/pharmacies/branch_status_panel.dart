import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/application_details.dart';
import '../../../providers/admin_overview_providers.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../services/admin_pharmacy_service.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'renewal_review_box.dart';

// Deactivate an active pharmacy, or activate an inactive one (wireframes A-09, A-10)
class BranchStatusPanel extends ConsumerStatefulWidget {
  const BranchStatusPanel({super.key, required this.details});

  final ApplicationDetails details;

  @override
  ConsumerState<BranchStatusPanel> createState() => _BranchStatusPanelState();
}

class _BranchStatusPanelState extends ConsumerState<BranchStatusPanel> {
  bool _busy = false;

  ApplicationDetails get d => widget.details;

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // Reload everything that shows this pharmacy's status
  void _refresh() {
    ref.invalidate(applicationDetailsProvider(d.id));
    ref.invalidate(deactivationReasonProvider(d.id));
    ref.invalidate(pharmacyListProvider);
    ref.invalidate(adminOverviewProvider);
  }

  // Run an action with a spinner and a friendly error
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      _tell(success);
    } catch (e) {
      _tell(AdminPharmacyService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Explain what happens, then ask for the reason
  Future<void> _deactivate() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Deactivate ${d.pharmacyName}?',
      subject: '${d.branchName} · ${d.displayId}',
      whatWillHappen: const [
        'The pharmacy is hidden from customers right away.',
        'Pending reservations are rejected; confirmed and ready ones are cancelled, '
            'and held stock is released.',
        'Customers with open reservations are notified with your reason.',
        'Carts with items from this pharmacy are emptied.',
        'Staff can no longer sign in; the owner can only send a renewed LTO.',
        'You can activate it again later.',
      ],
      actionLabel: 'Continue',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final reason = await showReasonDialog(
      context,
      title: 'Reason for deactivating',
      description: 'The owner and customers with open reservations see this reason.',
      actionLabel: 'Deactivate pharmacy',
      hint: 'e.g. The License to Operate has expired.',
    );
    if (reason == null) return;
    await _run(() => ref.read(adminPharmacyServiceProvider).deactivate(d.id, reason),
        'Pharmacy deactivated.');
  }

  // Ask first, then bring it back online
  Future<void> _activate() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Activate ${d.pharmacyName}?',
      subject: '${d.branchName} · ${d.displayId}',
      whatWillHappen: const [
        'Customers can find the pharmacy again.',
        'Its in-stock medicines show up in search again.',
        'The owner and staff can sign in and take reservations again.',
      ],
      actionLabel: 'Activate pharmacy',
    );
    if (ok) {
      await _run(() => ref.read(adminPharmacyServiceProvider).activate(d.id), 'Pharmacy activated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inactive = d.status == 'inactive';
    final reason = inactive ? ref.watch(deactivationReasonProvider(d.id)).value : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: AppSpacing.xl),
      const Text('PHARMACY STATUS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: AppSpacing.sm),

      if (inactive) ...[
        // Why it was taken offline
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Deactivated',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            if (reason != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(reason),
            ],
          ]),
        ),
        const SizedBox(height: AppSpacing.md),

        // A renewed LTO waiting for review, if any
        RenewalReviewBox(branchId: d.id),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _activate,
            child: const Text('Activate pharmacy'),
          ),
        ),
      ] else ...[
        const Text('The pharmacy is live and visible to customers.',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : _deactivate,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            child: const Text('Deactivate pharmacy'),
          ),
        ),
      ],
    ]);
  }
}