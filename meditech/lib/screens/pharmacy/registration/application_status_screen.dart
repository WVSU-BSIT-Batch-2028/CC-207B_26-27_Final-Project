import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/application_status.dart';
import '../../../providers/application_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_screen.dart';

// Application status for owners waiting for approval (wireframes Ph-09, Ph-10)
class ApplicationStatusScreen extends ConsumerWidget {
  const ApplicationStatusScreen({super.key, this.onBackToSignIn, this.onEditAndResubmit});

  final VoidCallback? onBackToSignIn; // routing fills these in later
  final VoidCallback? onEditAndResubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(myApplicationProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AsyncView<ApplicationStatus?>(
                  value: application,
                  onRetry: () => ref.invalidate(myApplicationProvider),
                  isEmpty: (a) => a == null,
                  emptyMessage: 'No application found for this account.',
                  builder: (a) => _StatusContent(
                    application: a!,
                    onBackToSignIn: onBackToSignIn,
                    onEditAndResubmit: onEditAndResubmit,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The title, tracker, reason, and buttons
class _StatusContent extends ConsumerWidget {
  const _StatusContent({required this.application, this.onBackToSignIn, this.onEditAndResubmit});

  final ApplicationStatus application;
  final VoidCallback? onBackToSignIn;
  final VoidCallback? onEditAndResubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = application;
    final date = DateFormat('MMM d, yyyy');
    final rejected = a.status == 'rejected';
    final approved = a.status == 'active';

    final title = switch (a.status) {
      'rejected' => 'Application not approved',
      'active' => 'Application approved',
      'inactive' => 'Pharmacy deactivated',
      _ => 'Application under review',
    };

    final intro = switch (a.status) {
      'rejected' => 'You can fix the details and resubmit. Your application keeps its place.',
      'active' => 'You can now set up your branch: add your staff and inventory.',
      'inactive' => 'Your pharmacy is hidden from patients. Contact the MediTech administrator.',
      _ => '${a.pharmacyName} (${a.displayId}) was submitted on ${date.format(a.submittedAt)}. '
          "We'll email you when it's reviewed. Your Owner account stays locked until then.",
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Meditech Logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('MediTech Pharmacy',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text(intro),
        const SizedBox(height: AppSpacing.lg),

        // Vertical tracker
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(children: [
              _TrackerStep(
                state: _StepState.done,
                title: 'Submitted',
                subtitle: date.format(a.submittedAt),
              ),
              _TrackerStep(
                state: rejected || approved ? _StepState.done : _StepState.current,
                title: rejected || approved ? 'Reviewed' : 'Under review',
                subtitle: rejected || approved ? '' : 'The administrator is checking your LTO',
              ),
              _TrackerStep(
                state: approved
                    ? _StepState.done
                    : rejected
                        ? _StepState.failed
                        : _StepState.waiting,
                title: rejected ? 'Not approved' : 'Approved',
                subtitle: rejected
                    ? 'See the reason below'
                    : approved && a.approvedAt != null
                        ? date.format(a.approvedAt!)
                        : 'You can sign in and set up your branch',
                isLast: true,
              ),
            ]),
          ),
        ),

        // The administrator's reason, if not approved
        if (rejected && a.rejectionReason != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reason from the administrator',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text(a.rejectionReason!),
            ]),
          ),
        ],

        // Buttons
        const SizedBox(height: AppSpacing.lg),
        if (rejected)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // Opens the form in edit mode; routing can replace this later
              onPressed: onEditAndResubmit ??
                  () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RegistrationScreen(editing: true),
                    ));
                    ref.invalidate(myApplicationProvider); // show the new status after
                  },
              child: const Text('Edit and resubmit'),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: onBackToSignIn, child: const Text('Back to sign in')),
          ),
      ],
    );
  }
}

// How a tracker step looks
enum _StepState { done, current, waiting, failed }

// One step in the vertical tracker
class _TrackerStep extends StatelessWidget {
  const _TrackerStep({required this.state, required this.title, required this.subtitle, this.isLast = false});

  final _StepState state;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      _StepState.done => (AppColors.primary, Icons.check),
      _StepState.current => (AppColors.primary, Icons.circle),
      _StepState.failed => (AppColors.danger, Icons.close),
      _StepState.waiting => (AppColors.border, null),
    };
    final filled = state != _StepState.waiting;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: filled ? color : Colors.white,
            child: icon == null
                ? Container(decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2)))
                : Icon(icon, size: state == _StepState.current ? 8 : 14, color: Colors.white),
          ),
          if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
        ]),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600,
                  color: state == _StepState.failed ? AppColors.danger : AppColors.text)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}