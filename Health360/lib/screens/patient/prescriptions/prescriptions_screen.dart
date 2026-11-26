import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/prescription.dart';
import '../../../services/prescription_service.dart';
import '../../../widgets/active_history_toggle.dart';
import '../../../widgets/h360_card.dart';
import '../../../widgets/state_views.dart';
import 'prescription_details_screen.dart';
import 'prescription_history_details_screen.dart';

/// The three things the list can be doing (same pattern as Home).
enum _LoadStatus { loading, ready, error }

/// The two tabs in the toggle at the top of the screen.
enum _PrescriptionTab { active, history }

/// Lists the patient's prescriptions, split into Active and History.
class PrescriptionsScreen extends StatefulWidget {
  /// Creates the patient prescriptions screen.
  const PrescriptionsScreen({super.key, this.refreshToken = 0});

  /// Changed by the shell when this data changes in Firestore; the screen
  /// then reloads quietly (keeps the list and selected filter on screen).
  final int refreshToken;

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

/// Holds the screen's state: what is loaded, which tab is chosen, any error.
class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  _PrescriptionTab _tab = _PrescriptionTab.active;
  List<Prescription> _prescriptions = [];
  String _error = '';

  /// Runs once when the screen is first created: start loading the data.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reloads quietly when the shell reports new data.
  @override
  void didUpdateWidget(covariant PrescriptionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load(showLoading: false);
  }

  /// Asks the service for the prescriptions and updates the screen.
  ///
  /// [showLoading] is false for pull-to-refresh so the list stays visible
  /// while it reloads. `mounted` is checked after every `await` because the
  /// user may have left the screen while we were waiting.
  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() => _status = _LoadStatus.loading);

    try {
      final items = await PrescriptionService.instance.fetchPrescriptions();
      if (!mounted) return;
      setState(() {
        _prescriptions = items;
        _status = _LoadStatus.ready;
        _error = '';
      });
    } on PrescriptionException catch (e) {
      // Known error from our service: show its friendly message.
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    } catch (_) {
      // Anything unexpected: still show a message instead of crashing.
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
        _status = _LoadStatus.error;
      });
    }
  }

  /// Returns only the prescriptions for the selected tab, in a sensible order.
  List<Prescription> _visiblePrescriptions() {
    final now = DateTime.now();

    if (_tab == _PrescriptionTab.active) {
      final active = _prescriptions.where((p) => p.isListedActiveOn(now)).toList();
      // Soonest refill first; prescriptions without a refill date go last.
      active.sort((a, b) {
        if (a.refillDate == null && b.refillDate == null) return 0;
        if (a.refillDate == null) return 1;
        if (b.refillDate == null) return -1;
        return a.refillDate!.compareTo(b.refillDate!);
      });
      return active;
    }

    final past = _prescriptions.where((p) => !p.isListedActiveOn(now)).toList();
    // Most recently finished first.
    past.sort((a, b) => b.endDate.compareTo(a.endDate));
    return past;
  }

  /// Opens the details page for the tapped card.
  ///
  /// Active prescriptions open Prescription Details (actions available);
  /// finished ones open the read-only History Details page.
  void _openDetails(Prescription prescription) {
    final Widget page = prescription.isListedActiveOn(DateTime.now())
        ? PrescriptionDetailsScreen(prescription: prescription)
        : PrescriptionHistoryDetailsScreen(prescription: prescription);

    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Builds the whole screen.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _load(showLoading: false),
        child: ListView(
          // Lets pull-to-refresh work even when the list is short or empty.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            // Heading
            Text(
              'Prescriptions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your medicines, reminders and refills.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),

            // Active / History toggle
            const SizedBox(height: AppSpacing.lg),
            ActiveHistoryToggle(
              showingActive: _tab == _PrescriptionTab.active,
              onChanged: (active) => setState(
                () => _tab =
                    active ? _PrescriptionTab.active : _PrescriptionTab.history,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Skeleton, error, empty state, or the list
            _buildContent(),
          ],
        ),
      ),
    );
  }

  /// Chooses what to show under the toggle based on the loading status.
  Widget _buildContent() {
    switch (_status) {
      // Loading: grey pulsing blocks shaped like the cards.
      case _LoadStatus.loading:
        return const Column(
          children: [
            SkeletonBox(height: 96, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 96, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 96, radius: AppRadius.md),
          ],
        );

      // Error: message from the service plus a retry button.
      case _LoadStatus.error:
        return ErrorState(message: _error, onRetry: _load);

      case _LoadStatus.ready:
        final items = _visiblePrescriptions();
        final showingActive = _tab == _PrescriptionTab.active;

        // Empty state: different text for each tab.
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.medication_rounded,
            title: showingActive
                ? 'No active prescriptions'
                : 'No prescription history',
            message: showingActive
                ? 'Medicines your doctor prescribes will appear here.'
                : 'Your finished prescriptions will appear here.',
          );
        }

        // List of prescription cards.
        return Column(
          children: [
            for (final prescription in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _PrescriptionCard(
                  prescription: prescription,
                  showingActive: showingActive,
                  onTap: () => _openDetails(prescription),
                ),
              ),
          ],
        );
    }
  }
}

/// One tappable prescription card: icon, name, instruction, date, arrow.
class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.showingActive,
    required this.onTap,
  });

  final Prescription prescription;

  /// Active cards show the refill date; history cards show the date prescribed.
  final bool showingActive;

  final VoidCallback onTap;

  /// The small grey line at the bottom of the card.
  String get _dateLine {
    if (showingActive) {
      // Not started yet: say so (it is not in Home's "Today's Medications").
      final now = DateTime.now();
      if (prescription.startDate.isAfter(DateTime(now.year, now.month, now.day))) {
        return 'Starts ${formatLongDate(prescription.startDate)}';
      }
      final refill = prescription.refillDate;
      return refill == null
          ? 'No refill scheduled'
          : 'Refill ${formatLongDate(refill)}';
    }
    return 'Prescribed ${formatLongDate(prescription.prescribedOn)}';
  }

  @override
  Widget build(BuildContext context) {
    return H360Card(
      onTap: onTap,
      child: Row(
        children: [
          // Medicine icon in a soft tinted square.
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name, instruction and date. Expanded stops long text overflowing.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prescription.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  prescription.instruction,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _dateLine,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Arrow telling the user the card opens something.
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
