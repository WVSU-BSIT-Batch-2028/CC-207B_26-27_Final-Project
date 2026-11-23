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

/// Loading states of the cards.
enum _LoadStatus { loading, ready, error }

/// Doctor Patient Details.
///
/// [onBack] returns to the Patients list.
/// [onViewFullRecord] opens the patient's full record.
/// [onAddConsultationNote] opens the consultation notes form.
class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onViewFullRecord,
    required this.onAddConsultationNote,
  });

  final Patient patient;
  final VoidCallback onBack;
  final VoidCallback onViewFullRecord;
  final VoidCallback onAddConsultationNote;

  @override
  State<PatientDetailsScreen> createState() =>
      _PatientDetailsScreenState();
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

  /// Loads the patient's conditions and allergies.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) {
      setState(() => _status = _LoadStatus.loading);
    }

    try {
      final detail =
          await PatientsService.instance.fetchPatientDetail(
        widget.patient.id,
      );

      if (!mounted) return;

      setState(() {
        _detail = detail;
        _status = _LoadStatus.ready;
        _error = '';
      });
    } on PatientsException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  /// Displays "None" when the list is empty.
  String _listOrNone(List<String> items) {
    return items.isEmpty ? 'None' : items.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          RecordsHeader(
            title: 'Patient Details',
            onBack: widget.onBack,
            backTooltip: 'Back to patients',
          ),
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

  /// Displays the patient's available profile information.
  Widget _buildProfile() {
    final patient = widget.patient;

    final demographics =
        patient.sex != null && patient.sex!.isNotEmpty &&
                patient.age != null
            ? '${patient.sex} - ${patient.age} years old'
            : patient.sex != null && patient.sex!.isNotEmpty
                ? patient.sex!
                : patient.age != null
                    ? '${patient.age} years old'
                    : 'Demographics not provided';

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.navy,
              width: 3,
            ),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 60,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          patient.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          demographics,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          patient.phone != null && patient.phone!.isNotEmpty
              ? patient.phone!
              : 'Contact number not provided',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Builds the information cards according to the loading state.
  List<Widget> _buildCards() {
    const gap = SizedBox(height: AppSpacing.md);

    switch (_status) {
      case _LoadStatus.loading:
        return [
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(
              height: 88,
              radius: AppRadius.md,
            ),
            gap,
          ],
        ];

      case _LoadStatus.error:
        return [
          ErrorState(
            message: _error,
            onRetry: _load,
          ),
        ];

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
          H360Button(
            label: 'View Full Record',
            onPressed: widget.onViewFullRecord,
          ),
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
