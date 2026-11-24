// Patient Lab Results = Patient Records > "Lab Results" pill (doctor side,
// inside the "Patients" tab).
//
// WHAT THE DOCTOR SEES: a "Patient Lab Results" header with a back arrow,
// three pills (Records / Lab Results / Prescriptions) with "Lab Results"
// selected, a "Laboratory Results" heading with a "View only" label, one
// card per lab test (name and date), newest first, and an "Add Lab Result"
// button pinned at the bottom.
//
// WHAT THE DOCTOR CAN DO: tap a card to open that result, tap "Add Lab
// Result" to enter a new one from the laboratory's report, tap the other
// pills to switch, pull down to refresh, tap the back arrow to return to
// Patient Details. Saved results are view only (they cannot be edited).
//
// WHERE THE DATA COMES FROM: PatientsService.fetchPatientLabResults (Firestore).
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/patient.dart';
import '../../../models/patient_lab_result.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/fade_slide_in.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../../records/widgets/records_header.dart';
import '../../records/widgets/records_scroll_body.dart';
import 'widgets/patient_lab_card.dart';
import 'widgets/patient_record_tab_bar.dart';

/// Loading states of this screen (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Doctor Patient Lab Results. [onBack] returns to Patient Details;
/// [onTabSelected] tells the Patients tab which pill was tapped;
/// [onOpenLabResult] tells it which lab result was tapped;
/// [onAddLabResult] that the "Add Lab Result" button was tapped.
class PatientLabResultsScreen extends StatefulWidget {
  const PatientLabResultsScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onTabSelected,
    required this.onOpenLabResult,
    required this.onAddLabResult,
  });

  /// The patient whose lab results are shown.
  final Patient patient;
  final VoidCallback onBack;
  final ValueChanged<PatientRecordTab> onTabSelected;
  final ValueChanged<PatientLabResult> onOpenLabResult;
  final VoidCallback onAddLabResult;

  @override
  State<PatientLabResultsScreen> createState() =>
      _PatientLabResultsScreenState();
}

class _PatientLabResultsScreenState extends State<PatientLabResultsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<PatientLabResult> _results = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for this patient's lab results and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final results = await PatientsService.instance
          .fetchPatientLabResults(widget.patient.id);
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _results = results;
        _status = _LoadStatus.ready;
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header: back arrow + title, then a thin divider (as in the prototype)
          RecordsHeader(
            title: 'Patient Lab Results',
            onBack: widget.onBack,
            backTooltip: 'Back to patient details',
          ),

          // Body: centered, max width, pull-to-refresh
          Expanded(
            child: RecordsScrollBody(
              onRefresh: () => _load(showSkeleton: false),
              children: _buildChildren(),
            ),
          ),

          // "Add Lab Result" stays pinned at the bottom once the list has loaded
          if (_status == _LoadStatus.ready)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                  child: H360Button(
                    label: 'Add Lab Result',
                    icon: Icons.add_circle_outline_rounded,
                    onPressed: widget.onAddLabResult,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the list content for the current state: loading, error, empty or ready.
  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.md);

    // The pills are always shown, with "Lab Results" selected.
    final pills = PatientRecordTabBar(
      selected: PatientRecordTab.labResults,
      onChanged: widget.onTabSelected,
    );

    switch (_status) {
      // Loading: skeleton placeholders shaped like the cards
      case _LoadStatus.loading:
        return [
          pills,
          gap,
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 88, radius: AppRadius.md),
            gap,
          ],
        ];

      // Error: message + "Try again" button
      case _LoadStatus.error:
        return [pills, gap, ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        return [
          pills,
          gap,

          // Heading + "View only" label
          Row(
            children: [
              Expanded(
                child: Text(
                  'Laboratory Results',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: 'View only',
                color: AppColors.primary,
                icon: Icons.visibility_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Saved results cannot be changed. If a test is repeated, add a new result.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          gap,

          // Empty: this patient has no lab results yet
          if (_results.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No lab results yet',
              message:
                  'Tap "Add Lab Result" to enter the numbers from the laboratory report.',
            ),

          // List of lab result cards (each fades in a little after the one above)
          for (var i = 0; i < _results.length; i++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i),
              child: PatientLabCard(
                result: _results[i],
                onTap: () => widget.onOpenLabResult(_results[i]),
              ),
            ),
            gap,
          ],
        ];
    }
  }
}
