// Patient Records > "Records" pill (doctor side, inside the "Patients" tab).
//
// WHAT THE DOCTOR SEES: a "Full Record" header with a back arrow, three pills
// (Records / Lab Results / Prescriptions) with "Records" selected, then the
// patient's Medical History (one card per condition), Allergies,
// Immunizations and Latest Vitals (BP, HR, weight).
//
// WHAT THE DOCTOR CAN DO: tap the other pills to open lab results or
// prescriptions, pull down to refresh, tap the back arrow to return to
// Patient Details.
//
// WHERE THE DATA COMES FROM: PatientsService.fetchPatientRecord (mock for
// now). Vitals are VitalSign objects, the same model the patient's Home uses.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/patient.dart';
import '../../../models/patient_record.dart';
import '../../../models/vital_sign.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/fade_slide_in.dart';
import '../../../widgets/state_views.dart';
import '../../records/widgets/records_header.dart';
import '../../records/widgets/records_scroll_body.dart';
import 'widgets/patient_info_card.dart';
import 'widgets/patient_record_tab_bar.dart';

/// Loading states of this screen (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Doctor Patient Records ("Records" pill). [onBack] returns to Patient
/// Details; [onTabSelected] tells the Patients tab which pill was tapped.
class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onTabSelected,
  });

  /// The patient whose record is shown.
  final Patient patient;
  final VoidCallback onBack;
  final ValueChanged<PatientRecordTab> onTabSelected;

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  PatientRecord? _record;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for this patient's record and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final record = await PatientsService.instance.fetchPatientRecord(widget.patient.id);
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _record = record;
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

  /// "None" when the list is empty, otherwise the items joined with commas.
  String _listOrNone(List<String> items) => items.isEmpty ? 'None' : items.join(', ');

  /// One line per vital, e.g. "BP: 120/60 mmHg". The number comes from
  /// VitalSign.value, so it is formatted exactly like on the patient's Home.
  /// A reading the model marks as "watch" gets "(Watch)" after it.
  String _vitalLine(VitalSign vital) {
    final name = switch (vital.type) {
      VitalType.bloodPressure => 'BP',
      VitalType.heartRate => 'HR',
      VitalType.weight => 'Weight',
      VitalType.sleep => 'Sleep',
    };
    final watch = vital.status == VitalStatus.watch ? ' (Watch)' : '';
    return '$name: ${vital.value} ${vital.unit}$watch';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header: back arrow + title, then a thin divider (as in the prototype)
          RecordsHeader(
            title: 'Full Record',
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
        ],
      ),
    );
  }

  /// Builds the list content for the current state: loading, error or ready.
  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.md);

    // The pills are always shown, with "Records" selected.
    final pills = PatientRecordTabBar(
      selected: PatientRecordTab.records,
      onChanged: widget.onTabSelected,
    );

    switch (_status) {
      // Loading: skeleton placeholders shaped like the cards
      case _LoadStatus.loading:
        return [
          pills,
          gap,
          for (var i = 0; i < 4; i++) ...[
            const SkeletonBox(height: 88, radius: AppRadius.md),
            gap,
          ],
        ];

      // Error: message + "Try again" button
      case _LoadStatus.error:
        return [pills, gap, ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        final record = _record!;
        return [
          pills,
          gap,

          // Medical History: one card per condition
          Text(
            'Medical History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
          gap,
          if (record.history.isEmpty)
            const PatientInfoCard(
              icon: Icons.medication_outlined,
              label: 'Medical History',
              value: 'None recorded',
            ),
          for (final entry in record.history) ...[
            PatientInfoCard(
              icon: Icons.medication_outlined,
              label: entry.condition,
              value: 'Diagnosed: ${entry.diagnosedYear}',
            ),
            gap,
          ],

          // Allergies, Immunizations and Latest Vitals (each fades in after the one above)
          FadeSlideIn(
            child: PatientInfoCard(
              icon: Icons.warning_amber_rounded,
              label: 'Allergies',
              value: _listOrNone(record.allergies),
            ),
          ),
          gap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: PatientInfoCard(
              icon: Icons.vaccines_outlined,
              label: 'Immunizations',
              value: _listOrNone(record.immunizations),
            ),
          ),
          gap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: PatientInfoCard(
              icon: Icons.favorite_border_rounded,
              label: 'Latest Vitals',
              value: record.vitals.isEmpty
                  ? 'No vitals recorded'
                  : record.vitals.map(_vitalLine).join('\n'),
            ),
          ),
          gap,
        ];
    }
  }
}
