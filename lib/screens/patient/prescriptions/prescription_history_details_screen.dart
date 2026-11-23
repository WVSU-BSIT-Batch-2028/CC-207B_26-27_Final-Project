import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/prescription.dart';
import '../../../models/taken_history.dart';
import '../../../services/prescription_service.dart';
import '../../../widgets/prescription_info_card.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/taken_history_card.dart';

/// Loading status of the "Doses taken" card only.
enum _LoadStatus { loading, ready, error }

/// Shows a finished prescription in read-only form.
class PrescriptionHistoryDetailsScreen extends StatefulWidget {
  /// Creates the history details screen for [prescription].
  const PrescriptionHistoryDetailsScreen({
    super.key,
    required this.prescription,
  });

  /// The finished prescription to show (passed in from the list).
  final Prescription prescription;

  @override
  State<PrescriptionHistoryDetailsScreen> createState() =>
      _PrescriptionHistoryDetailsScreenState();
}

/// Holds the loading status and the loaded taken-dose history.
class _PrescriptionHistoryDetailsScreenState
    extends State<PrescriptionHistoryDetailsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  String _error = '';
  TakenHistory? _history;

  Prescription get _rx => widget.prescription;

  /// Start loading the taken-dose history when the screen opens.
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Loads the "Doses taken" data. Only that card waits for it: the other
  /// cards come from the prescription we already have, so they show at once.
  Future<void> _loadHistory() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final history =
          await PrescriptionService.instance.fetchTakenHistory(_rx.id);
      if (!mounted) return;
      setState(() {
        _history = history;
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

  /// "1 day" / "7 days".
  String _daysText(int days) => days == 1 ? '1 day' : '$days days';

  /// Builds the screen: app bar plus the list of cards.
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headingStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
    );
    final notes = _rx.notes;
    final lastRefill = _rx.lastRefill;

    return Scaffold(
      appBar: AppBar(title: const Text('Prescription Details')),
      body: SafeArea(
        // Centred with a max width so it also looks right on a wide window.
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
              children: [
                // Medicine
                PrescriptionInfoCard(
                  icon: Icons.medication_rounded,
                  children: [
                    Text(_rx.title, style: headingStyle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _rx.form,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_rx.instruction} for ${_daysText(_rx.durationDays)}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Course ended ${formatLongDate(_rx.lastDay)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Doctor's notes (only when the doctor wrote some)
                if (notes != null && notes.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  PrescriptionInfoCard(
                    icon: Icons.sticky_note_2_outlined,
                    children: [
                      Text("Doctor's notes", style: headingStyle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notes,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],

                // Prescribed by
                const SizedBox(height: AppSpacing.md),
                PrescriptionInfoCard(
                  icon: Icons.person_outline_rounded,
                  children: [
                    Text('Prescribed by', style: headingStyle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _rx.prescribedBy,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    // The phone is optional: only show it when there is one.
                    if (_rx.doctorPhone != null && _rx.doctorPhone!.isNotEmpty)
                      Text(
                        _rx.doctorPhone!,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatLongDate(_rx.prescribedOn),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                // Last refill
                const SizedBox(height: AppSpacing.md),
                PrescriptionInfoCard(
                  icon: Icons.local_pharmacy_outlined,
                  children: [
                    Text('Last Refill', style: headingStyle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      lastRefill == null
                          ? 'No refill was made.'
                          : formatLongDate(lastRefill),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                // Doses taken (loads on its own)
                const SizedBox(height: AppSpacing.md),
                _buildTakenHistory(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Skeleton while loading, an error with retry, or the "Doses taken" card.
  Widget _buildTakenHistory() {
    switch (_status) {
      case _LoadStatus.loading:
        return const SkeletonBox(height: 130, radius: AppRadius.md);

      case _LoadStatus.error:
        return ErrorState(message: _error, onRetry: _loadHistory);

      case _LoadStatus.ready:
        return TakenHistoryCard(
          history: _history ?? const TakenHistory([]),
          courseDays: _rx.durationDays,
        );
    }
  }
}
