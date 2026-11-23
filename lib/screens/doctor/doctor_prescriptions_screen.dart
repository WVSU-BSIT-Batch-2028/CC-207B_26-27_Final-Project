// Doctor Prescriptions (opened from the doctor's Menu > Prescriptions, and from
// the dashboard). Matches the "Doctor Prescription" page of the prototype.
//
// WHAT THE DOCTOR SEES: a "Prescriptions" header with a back arrow, an
// Active / History switch, one card per prescription (medicine and dose, how
// to take it, the date range, which patient it is for, and a status chip), and
// an "Add Prescription" button pinned at the bottom.
//
// WHAT THE DOCTOR CAN DO: switch Active / History, pull down to refresh, tap
// "Add Prescription" (first choose the patient, then fill in the form), or tap
// the back arrow.
//
// WHERE THE DATA COMES FROM: PatientsService (Firestore `prescriptions`). It
// is the same collection the patient's Prescriptions screen reads, so a
// prescription saved here shows up on the patient's side.
//
// SHARED WIDGETS USED: RecordsHeader, ActiveHistoryToggle, H360Card,
// StatusChip, H360Button, SkeletonBox / EmptyState / ErrorState.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_format.dart';
import '../../models/doctor_prescription.dart';
import '../../models/patient.dart';
import '../../services/patients_service.dart';
import '../../widgets/active_history_toggle.dart';
import '../../widgets/h360_button.dart';
import '../../widgets/h360_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../records/widgets/records_header.dart';
import '../records/widgets/records_scroll_body.dart';
import 'patients/add_prescription_screen.dart';

/// The three things the list can be doing (same pattern as Home).
enum _LoadStatus { loading, ready, error }

/// One prescription together with the patient it was written for.
class _PatientPrescription {
  const _PatientPrescription({required this.patient, required this.prescription});

  final Patient patient;
  final DoctorPrescription prescription;

  /// Last day the patient takes the medicine (the day before the end date).
  DateTime get lastDay {
    final s = prescription.startDate;
    return DateTime(s.year, s.month, s.day + prescription.durationDays - 1);
  }

  /// Active until the course has finished (same rule as the patient's side).
  bool isActiveOn(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final s = prescription.startDate;
    final end = DateTime(s.year, s.month, s.day + prescription.durationDays);
    return today.isBefore(end);
  }
}

/// Doctor Prescriptions screen (a full page pushed on top of the doctor shell).
class DoctorPrescriptionsScreen extends StatefulWidget {
  const DoctorPrescriptionsScreen({super.key});

  @override
  State<DoctorPrescriptionsScreen> createState() => _DoctorPrescriptionsScreenState();
}

class _DoctorPrescriptionsScreenState extends State<DoctorPrescriptionsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  bool _showingActive = true;
  List<Patient> _patients = const [];
  List<_PatientPrescription> _items = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads every patient, then each patient's prescriptions, and merges them
  /// into one list. [showSkeleton] is false for pull-to-refresh.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);

    try {
      final patients = await PatientsService.instance.fetchPatients();

      // One request per patient, all at the same time.
      final perPatient = await Future.wait(
        patients.map((patient) async {
          final list = await PatientsService.instance.fetchPatientPrescriptions(patient.id);
          return [
            for (final rx in list) _PatientPrescription(patient: patient, prescription: rx),
          ];
        }),
      );

      // The doctor may have left the screen while we waited.
      if (!mounted) return;

      final all = perPatient.expand((x) => x).toList()
        ..sort((a, b) => b.prescription.startDate.compareTo(a.prescription.startDate));

      setState(() {
        _patients = patients;
        _items = all;
        _status = _LoadStatus.ready;
        _error = '';
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    } catch (_) {
      // Anything unexpected still shows a message instead of a blank screen.
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load prescriptions. Please try again.';
        _status = _LoadStatus.error;
      });
    }
  }

  /// Only the prescriptions of the selected tab.
  List<_PatientPrescription> get _visible {
    final now = DateTime.now();
    return _items.where((i) => i.isActiveOn(now) == _showingActive).toList();
  }

  /// Add Prescription: the form needs a patient, so the doctor picks one first.
  Future<void> _addPrescription() async {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no patients to prescribe for yet.')),
      );
      return;
    }

    final patient = await showModalBottomSheet<Patient>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PatientPicker(patients: _patients),
    );
    if (patient == null || !mounted) return;

    // The form is a full page. After saving (or Back) it closes itself.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          body: AddPrescriptionScreen(
            patient: patient,
            onBack: () => Navigator.of(pageContext).pop(),
            onSaved: () => Navigator.of(pageContext).pop(),
          ),
        ),
      ),
    );

    // Back here: reload so the new prescription appears in the list.
    if (mounted) _load(showSkeleton: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: back arrow + title
            RecordsHeader(
              title: 'Prescriptions',
              onBack: () => Navigator.of(context).maybePop(),
              backTooltip: 'Back',
            ),

            // Body: toggle + list (or loading / empty / error)
            Expanded(
              child: RecordsScrollBody(
                onRefresh: () => _load(showSkeleton: false),
                children: _buildChildren(),
              ),
            ),

            // "Add Prescription" stays pinned at the bottom once loaded
            if (_status == _LoadStatus.ready) _buildAddButton(),
          ],
        ),
      ),
    );
  }

  /// What goes inside the scrolling body for the current state.
  List<Widget> _buildChildren() {
    // Loading: three grey placeholder cards
    if (_status == _LoadStatus.loading) {
      return const [
        SkeletonBox(height: 44),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 110),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 110),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 110),
      ];
    }

    // Error: message with a retry button
    if (_status == _LoadStatus.error) {
      return [ErrorState(message: _error, onRetry: _load)];
    }

    final visible = _visible;
    return [
      // Active / History switch
      ActiveHistoryToggle(
        showingActive: _showingActive,
        onChanged: (value) => setState(() => _showingActive = value),
      ),
      const SizedBox(height: AppSpacing.md),

      // Empty state for the selected tab
      if (visible.isEmpty)
        EmptyState(
          icon: Icons.medication_outlined,
          title: _showingActive ? 'No active prescriptions' : 'No past prescriptions',
          message: _showingActive
              ? 'Tap Add Prescription to write one for a patient.'
              : 'Finished prescriptions will appear here.',
        )
      else
        for (final item in visible) ...[
          _PrescriptionTile(item: item, active: _showingActive),
          const SizedBox(height: AppSpacing.md),
        ],
    ];
  }

  /// The large "Add Prescription" button (same as the patient prescriptions page).
  Widget _buildAddButton() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: H360Button(label: 'Add Prescription', onPressed: _addPrescription),
        ),
      ),
    );
  }
}

/// One card: icon, medicine and dose, how to take it, date range, patient, chip.
class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({required this.item, required this.active});

  final _PatientPrescription item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = item.prescription;
    final note = p.notes;

    return H360Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tile on the left
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.medication_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  p.instructionText,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  '${formatShortDate(p.startDate)} - ${formatLongDate(item.lastDay)}',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                Text(
                  'Patient: ${item.patient.name}',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Note: $note',
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                StatusChip(
                  label: active ? 'Active' : 'Completed',
                  color: active ? AppColors.success : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the patients; tapping one returns it to the caller.
class _PatientPicker extends StatelessWidget {
  const _PatientPicker({required this.patients});

  final List<Patient> patients;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Text(
              'Choose a patient',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
            ),
          ),
          for (final patient in patients)
            ListTile(
              leading: Icon(Icons.person_outline_rounded, color: AppColors.primary),
              title: Text(patient.name),
              subtitle: Text(patient.condition),
              onTap: () => Navigator.of(context).pop(patient),
            ),
        ],
      ),
    );
  }
}
