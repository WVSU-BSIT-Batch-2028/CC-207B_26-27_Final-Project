// Patient Prescriptions = Patient Records > "Prescriptions" pill (doctor side,
// inside the "Patients" tab).
//
// WHAT THE DOCTOR SEES: a "Patient Prescriptions" header with a back arrow,
// three pills (Records / Lab Results / Prescriptions) with "Prescriptions"
// selected, one card per prescription (medicine and dose, how to take it,
// refill date, and the doctor's note if there is one), and an "Add
// Prescription" button pinned at the bottom.
//
// WHAT THE DOCTOR CAN DO: tap "Add Prescription" to write a new one, tap the
// other pills to switch, pull down to refresh, tap the back arrow to return
// to Patient Details.
//
// WHERE THE DATA COMES FROM: PatientsService.fetchPatientPrescriptions (mock).
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/patient.dart';
import '../../../models/prescription.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/fade_slide_in.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/state_views.dart';
import '../../records/widgets/records_header.dart';
import '../../records/widgets/records_scroll_body.dart';
import 'widgets/patient_record_tab_bar.dart';
import 'widgets/prescription_card.dart';

/// Loading states of this screen (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Doctor Patient Prescriptions. [onBack] returns to Patient Details;
/// [onTabSelected] tells the Patients tab which pill was tapped;
/// [onAddPrescription] that the "Add Prescription" button was tapped.
class PatientPrescriptionsScreen extends StatefulWidget {
  const PatientPrescriptionsScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onTabSelected,
    required this.onAddPrescription,
  });

  /// The patient whose prescriptions are shown.
  final Patient patient;
  final VoidCallback onBack;
  final ValueChanged<PatientRecordTab> onTabSelected;
  final VoidCallback onAddPrescription;

  @override
  State<PatientPrescriptionsScreen> createState() => _PatientPrescriptionsScreenState();
}

class _PatientPrescriptionsScreenState extends State<PatientPrescriptionsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<Prescription> _prescriptions = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for this patient's prescriptions and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final items = await PatientsService.instance.fetchPatientPrescriptions(widget.patient.id);
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _prescriptions = items;
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
            title: 'Patient Prescriptions',
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

          // "Add Prescription" stays pinned at the bottom once the list has loaded
          if (_status == _LoadStatus.ready) _buildAddButton(),
        ],
      ),
    );
  }

  /// The large "Add Prescription" button (H360Button, not shrunk, as the
  /// team feedback asks for main buttons).
  Widget _buildAddButton() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: H360Button(
            label: 'Add Prescription',
            icon: Icons.add_circle_outline_rounded,
            onPressed: widget.onAddPrescription,
          ),
        ),
      ),
    );
  }

  /// Builds the list content for the current state: loading, error, empty or ready.
  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.md);

    // The pills are always shown, with "Prescriptions" selected.
    final pills = PatientRecordTabBar(
      selected: PatientRecordTab.prescriptions,
      onChanged: widget.onTabSelected,
    );

    switch (_status) {
      // Loading: skeleton placeholders shaped like the cards
      case _LoadStatus.loading:
        return [
          pills,
          gap,
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 128, radius: AppRadius.md),
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

          // Empty: this patient has no prescriptions yet
          if (_prescriptions.isEmpty)
            const EmptyState(
              icon: Icons.medication_outlined,
              title: 'No prescriptions yet',
              message: 'Tap "Add Prescription" to write the first one for this patient.',
            ),

          // List of prescription cards (each fades in a little after the one above)
          for (var i = 0; i < _prescriptions.length; i++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i),
              child: PrescriptionCard(prescription: _prescriptions[i]),
            ),
            gap,
          ],
        ];
    }
  }
}
