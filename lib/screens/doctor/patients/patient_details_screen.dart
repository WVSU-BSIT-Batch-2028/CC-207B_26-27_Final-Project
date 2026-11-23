// Patient Details (doctor side, inside the "Patients" tab).
//
// WHAT THE DOCTOR SEES: a "Patient Details" header with a back arrow, the
// patient's avatar, name, sex and age, and phone number, then three cards
// (Medical Conditions, Allergies, Last Visit) and a "View Full Record" button.
//
// WHAT THE DOCTOR CAN DO: tap "View Full Record", tap "Add Consultation Notes",
// pull down to refresh, tap
// the back arrow to return to the Patients list.
//
// WHERE THE DATA COMES FROM: the name, age, sex, phone and last visit come
// from the Patient that was tapped in the list. The conditions and allergies
// are loaded by PatientsService.fetchPatientDetail (mock for now), so only
// the cards need a loading and an error state.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/patient.dart';
import '../../../models/patient_detail.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/state_views.dart';
import '../../records/widgets/records_header.dart';
import '../../records/widgets/records_scroll_body.dart';
import 'widgets/patient_info_card.dart';

/// Loading states of the cards (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Doctor Patient Details. [onBack] returns to the Patients list;
/// [onViewFullRecord] opens the patient's full record; [onAddConsultationNote]
/// opens the form to write consultation notes.
class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onViewFullRecord,
    required this.onAddConsultationNote,
  });

  /// The patient that was tapped in the list.
  final Patient patient;
  final VoidCallback onBack;
  final VoidCallback onViewFullRecord;
  final VoidCallback onAddConsultationNote;

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  PatientDetail? _detail;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for this patient's conditions and allergies.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final detail = await PatientsService.instance.fetchPatientDetail(widget.patient.id);
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  /// "Hypertension, Asthma", or "None" when the list is empty.
  String _listOrNone(List<String> items) => items.isEmpty ? 'None' : items.join(', ');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header: back arrow + title, then a thin divider (as in the prototype)
          RecordsHeader(
            title: 'Patient Details',
            onBack: widget.onBack,
            backTooltip: 'Back to patients',
          ),

          // Body: centered, max width, pull-to-refresh
          Expanded(
            child: RecordsScrollBody(
              onRefresh: () => _load(showSkeleton: false),
              children: [
                _buildProfile(),
                const SizedBox(height: AppSpacing.lg),
                ..._buildCards(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar, name, "Female - 21 years old" and phone. Always shown,
  /// because it comes from the Patient we already have.
  Widget _buildProfile() {
    final patient = widget.patient;
    // "Female - 21 years old", leaving out whatever the profile does not have.
    final details = [
      if (patient.sex != null && patient.sex!.isNotEmpty) patient.sex!,
      if (patient.age != null) '${patient.age} years old',
    ].join(' - ');
    return Column(
      children: [
        // Large avatar circle
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.navy, width: 3),
          ),
          child: Icon(Icons.person_outline_rounded, size: 60, color: AppColors.navy),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          patient.name,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (details.isNotEmpty)
          Text(
            details,
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
        if (patient.phone != null && patient.phone!.isNotEmpty)
          Text(
            patient.phone!,
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
      ],
    );
  }

  /// The three info cards and the button, for the current state:
  /// loading, error or ready.
  List<Widget> _buildCards() {
    const gap = SizedBox(height: AppSpacing.md);

    switch (_status) {
      // Loading: skeleton placeholders shaped like the cards
      case _LoadStatus.loading:
        return [
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 88, radius: AppRadius.md),
            gap,
          ],
        ];

      // Error: message + "Try again" button
      case _LoadStatus.error:
        return [ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        final detail = _detail!;
        return [
          PatientInfoCard(
            icon: Icons.medication_outlined,
            label: 'Medical Conditions',
            value: _listOrNone(detail.conditions),
          ),
          gap,
          PatientInfoCard(
            icon: Icons.warning_amber_rounded,
            label: 'Allergies',
            value: _listOrNone(detail.allergies),
          ),
          gap,
          PatientInfoCard(
            icon: Icons.calendar_today_outlined,
            label: 'Last Visit',
            value: widget.patient.lastVisit == null
                ? 'No visits yet'
                : formatLongDate(widget.patient.lastVisit!),
          ),
          const SizedBox(height: AppSpacing.lg),
          H360Button(label: 'View Full Record', onPressed: widget.onViewFullRecord),
          gap,
          H360Button(
            label: 'Add Consultation Notes',
            icon: Icons.note_add_outlined,
            inverted: true,
            onPressed: widget.onAddConsultationNote,
          ),
        ];
    }
  }
}
