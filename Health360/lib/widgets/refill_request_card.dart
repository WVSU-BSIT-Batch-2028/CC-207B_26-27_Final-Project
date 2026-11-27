import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/date_format.dart';
import '../models/refill_request.dart';
import 'h360_button.dart';
import 'prescription_info_card.dart';
import 'refill_status_chip.dart';
import 'dialog_frame.dart';

/// Shows a patient's refill request to the doctor. While the request is
/// pending it has Approve and Decline buttons; once answered it only shows
/// the status.
///
/// The card only draws the request and asks the doctor to confirm. The screen
/// that uses it supplies [onRespond], which sends the answer, so the card does
/// not need to know how patients are identified.
class RefillRequestCard extends StatefulWidget {
  const RefillRequestCard({
    super.key,
    required this.medicineTitle,
    required this.request,
    required this.onRespond,
    required this.onAnswered,
  });

  /// e.g. "Amoxicillin 500mg", used in the confirmation dialog.
  final String medicineTitle;

  /// The request to show.
  final RefillRequest request;

  /// Sends the doctor's answer. Returns null when it worked, or the error
  /// message to show when it did not.
  final Future<String?> Function(RefillStatus answer) onRespond;

  /// Called after a successful answer, so the screen can reload its list.
  final VoidCallback onAnswered;

  @override
  State<RefillRequestCard> createState() => _RefillRequestCardState();
}

class _RefillRequestCardState extends State<RefillRequestCard> {
  /// True while Approve or Decline is being sent (buttons show a spinner).
  bool _responding = false;

  /// Approve or decline. Asks to confirm first, because the patient will see
  /// the answer and it cannot be changed afterwards.
  Future<void> _respond(RefillStatus answer) async {
    final approve = answer == RefillStatus.approved;
    final title = widget.medicineTitle;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogFrame(child: AlertDialog(
        title: Text(approve ? 'Approve this refill?' : 'Decline this refill?'),
        content: Text(
          approve
              ? 'The patient will see that the refill for $title was approved.'
              : 'The patient will see that the refill for $title was declined, and can send a new request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(approve ? 'Approve' : 'Decline'),
          ),
        ],
      )),
    );

    // The doctor tapped Cancel, tapped outside, or left the screen.
    if (confirmed != true || !mounted) return;

    setState(() => _responding = true);
    final error = await widget.onRespond(answer);
    if (!mounted) return;
    setState(() => _responding = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ?? (approve ? 'Refill approved.' : 'Refill declined.'),
          ),
        ),
      );
    if (error == null) widget.onAnswered();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrescriptionInfoCard(
          icon: Icons.local_pharmacy_outlined,
          children: [
            Text(
              'Refill request',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Icon AND text, so the status never relies on colour alone.
            RefillStatusChip(status: request.status),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Requested ${formatLongDate(request.requestedAt)}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),

        // Buttons only while the request is waiting for an answer.
        if (request.status == RefillStatus.pending) ...[
          const SizedBox(height: AppSpacing.sm),
          H360Button(
            label: 'Approve Refill',
            icon: Icons.check_rounded,
            isLoading: _responding,
            onPressed:
                _responding ? null : () => _respond(RefillStatus.approved),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed:
                _responding ? null : () => _respond(RefillStatus.declined),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Decline Refill'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ],
    );
  }
}