import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/prescription.dart';
import '../../../models/refill_request.dart';
import '../../../services/prescription_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/prescription_info_card.dart';
import '../../../widgets/refill_status_chip.dart';
import '../../../widgets/state_views.dart';
import 'set_reminder_screen.dart';

/// Loading status of the extra data (taken today, refill request).
enum _LoadStatus { loading, ready, error }

/// Shows everything about one prescription and lets the patient act on it.
class PrescriptionDetailsScreen extends StatefulWidget {
  /// Creates the details screen for [prescription].
  const PrescriptionDetailsScreen({super.key, required this.prescription});

  /// The prescription to show (passed in from the list).
  final Prescription prescription;

  @override
  State<PrescriptionDetailsScreen> createState() =>
      _PrescriptionDetailsScreenState();
}

/// Holds what was loaded and which button is busy.
class _PrescriptionDetailsScreenState extends State<PrescriptionDetailsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  String _error = '';

  /// Was this medicine already marked as taken today?
  bool _takenToday = false;

  /// The patient's refill request for this medicine, or null if none.
  RefillRequest? _refill;

  /// True while a button's request is running (shows a spinner on it).
  bool _savingTaken = false;
  bool _savingRefill = false;

  Prescription get _rx => widget.prescription;

  /// Load the extra data as soon as the screen opens.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads taken-today and the refill request. Same loading / error pattern
  /// as the list screen; there is no "empty" state because the prescription
  /// itself is always passed in.
  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final activity =
          await PrescriptionService.instance.fetchActivity(_rx.id);
      if (!mounted) return;
      setState(() {
        _takenToday = activity.takenToday;
        _refill = activity.refillRequest;
        _status = _LoadStatus.ready;
      });
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
        _status = _LoadStatus.error;
      });
    }
  }

  /// Shows a short message at the bottom of the screen.
  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// "Mark as Taken": saves today's dose and offers an Undo in the snack bar.
  Future<void> _markTaken() async {
    setState(() => _savingTaken = true);
    try {
      await PrescriptionService.instance.setTakenToday(_rx.id, true);
      if (!mounted) return;
      setState(() {
        _takenToday = true;
        _savingTaken = false;
      });
      _showMessage(
        '${_rx.title} marked as taken.',
        action: SnackBarAction(label: 'Undo', onPressed: _undoTaken),
      );
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      setState(() => _savingTaken = false);
      _showMessage(e.message);
    }
  }

  /// Undo a "taken" mark made by mistake.
  Future<void> _undoTaken() async {
    try {
      await PrescriptionService.instance.setTakenToday(_rx.id, false);
      if (!mounted) return;
      setState(() => _takenToday = false);
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    }
  }

  /// Opens the Set a Reminder screen for this prescription.
  void _openReminder() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetReminderScreen(prescription: _rx),
      ),
    );
  }

  /// "Request Refill": asks for confirmation first, then sends the request.
  Future<void> _requestRefill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request a refill?'),
        content: Text(
          '${_rx.prescribedBy} will review your refill request for ${_rx.title}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    // The user tapped Cancel, tapped outside, or left the screen.
    if (confirmed != true || !mounted) return;

    setState(() => _savingRefill = true);
    try {
      final request =
          await PrescriptionService.instance.requestRefill(_rx.id);
      if (!mounted) return;
      setState(() {
        _refill = request;
        _savingRefill = false;
      });
      _showMessage('Refill request sent. Your doctor will review it.');
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      setState(() => _savingRefill = false);
      _showMessage(e.message);
    }
  }

  /// A refill can be requested when it is available and there is no request
  /// waiting or approved (a declined request can be sent again).
  bool get _canRequestRefill {
    if (!_rx.isRefillAvailableOn(DateTime.now())) return false;
    final request = _refill;
    return request == null || request.status == RefillStatus.declined;
  }

  /// Text on the refill button, matching where the request is.
  String get _refillButtonLabel {
    switch (_refill?.status) {
      case RefillStatus.pending:
        return 'Refill Requested';
      case RefillStatus.approved:
        return 'Refill Approved';
      case RefillStatus.declined:
      case null:
        return 'Request Refill';
    }
  }

  /// Builds the screen: app bar plus the body for the current status.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription Details')),
      body: SafeArea(
        // Centre the content with a max width so it also looks right on a
        // wide browser window.
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [_buildBody()],
            ),
          ),
        ),
      ),
    );
  }

  /// Skeleton while loading, error with retry, or the real content.
  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Column(
          children: [
            SkeletonBox(height: 110, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 110, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 110, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 52, radius: AppRadius.md),
          ],
        );

      case _LoadStatus.error:
        return ErrorState(message: _error, onRetry: _load);

      case _LoadStatus.ready:
        return _buildDetails();
    }
  }

  /// The cards and buttons.
  Widget _buildDetails() {
    final textTheme = Theme.of(context).textTheme;
    final refillDate = _rx.refillDate;
    final refillAvailable = _rx.isRefillAvailableOn(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Medicine
        PrescriptionInfoCard(
          icon: Icons.medication_rounded,
          children: [
            Text(
              _rx.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _rx.form,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_rx.instruction} for ${_daysText(_rx.durationDays)}',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),

        // Doctor's notes (only when the doctor wrote some)
        if (_rx.notes != null && _rx.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          PrescriptionInfoCard(
            icon: Icons.sticky_note_2_outlined,
            children: [
              Text(
                "Doctor's notes",
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _rx.notes!,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
            ],
          ),
        ],

        // Prescribed by
        const SizedBox(height: AppSpacing.md),
        PrescriptionInfoCard(
          icon: Icons.person_outline_rounded,
          children: [
            Text(
              'Prescribed by',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _rx.prescribedBy,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            // The phone is optional: only show it when the prescription has one.
            if (_rx.doctorPhone != null && _rx.doctorPhone!.isNotEmpty)
              Text(
                _rx.doctorPhone!,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatLongDate(_rx.prescribedOn),
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),

        // Refill (date, hint, and request status)
        const SizedBox(height: AppSpacing.md),
        PrescriptionInfoCard(
          icon: Icons.local_pharmacy_outlined,
          children: [
            Text(
              refillAvailable ? 'Refill Available' : 'Refill',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              refillDate == null
                  ? 'No refill scheduled.'
                  : 'Available from ${formatLongDate(refillDate)}',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            if (refillDate != null && !refillAvailable) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You can request a refill on that date.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
            if (_refill != null) ...[
              const SizedBox(height: AppSpacing.sm),
              RefillStatusChip(status: _refill!.status),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Requested ${formatLongDate(_refill!.requestedAt)}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ],
          ],
        ),

        // Buttons
        const SizedBox(height: AppSpacing.lg),
        H360Button(
          label: _takenToday ? 'Taken Today' : 'Mark as Taken',
          icon: _takenToday
              ? Icons.check_circle_rounded
              : Icons.check_rounded,
          isLoading: _savingTaken,
          // Disabled (null) once taken; the Undo is in the snack bar.
          onPressed: _takenToday ? null : _markTaken,
        ),
        const SizedBox(height: AppSpacing.sm),
        _outlinedButton(
          label: 'Set a Reminder',
          icon: Icons.alarm_rounded,
          onPressed: _openReminder,
        ),
        const SizedBox(height: AppSpacing.sm),
        _outlinedButton(
          label: _refillButtonLabel,
          icon: Icons.autorenew_rounded,
          loading: _savingRefill,
          onPressed: _canRequestRefill ? _requestRefill : null,
        ),
      ],
    );
  }

  /// "1 day" / "7 days".
  String _daysText(int days) => days == 1 ? '1 day' : '$days days';

  /// Full-width outlined button that matches [H360Button]'s size and shape.
  Widget _outlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}
