// Add Consultation Notes (doctor side, inside the "Patients" tab).
//
// This screen is not in the prototype: it is how the doctor WRITES the notes
// that the patient reads in Records > Consultations > Medical Record.
//
// WHAT THE DOCTOR SEES: an "Add Consultation Notes" header with a back arrow,
// who the notes are for, and a form: Appointment (optional), Department, Date
// of visit, Assessment / Diagnosis, Treatment / Recommendations, and a Save
// button.
//
// LINKING TO AN APPOINTMENT: the Appointment dropdown lists this patient's
// completed appointments (from AppointmentService). Choosing one fills in the
// date and department and saves the appointment's id in `appointmentId`, so
// the notes belong to that visit.
//
// WHAT THE DOCTOR CAN DO: fill in the form and tap Save. Both notes are
// required, so Save shows a message under any field left empty. When it is
// saved the doctor sees a confirmation popup and, after OK, returns to the
// patient's details.
//
// WHERE THE DATA GOES: PatientsService.addConsultationNote saves it in the
// `consultations` collection of Firestore. The doctor's name is added
// automatically from the signed-in account.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/appointment.dart';
import '../../../models/appointment_status.dart';
import '../../../models/patient.dart';
import '../../../services/appointment_service.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/h360_card.dart';
import '../../records/widgets/records_header.dart';
import 'widgets/prescription_added_dialog.dart';

/// Doctor Add Consultation Notes. [onBack] cancels and returns to Patient
/// Details; [onSaved] is called after the confirmation popup is closed.
class AddConsultationNoteScreen extends StatefulWidget {
  const AddConsultationNoteScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onSaved,
  });

  /// The patient the notes are for.
  final Patient patient;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  State<AddConsultationNoteScreen> createState() => _AddConsultationNoteScreenState();
}

class _AddConsultationNoteScreenState extends State<AddConsultationNoteScreen> {
  /// Used to run every field's validator when Save is tapped.
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();

  /// The usual choices for Department. An appointment with another specialty
  /// adds its own choice to [_departments].
  static const List<String> _baseDepartments = [
    'General Consultation',
    'Follow-up Check-up',
    'Internal Medicine',
    'Pediatrics',
  ];

  List<String> _departments = List.of(_baseDepartments);
  String _department = _baseDepartments.first;
  DateTime _date = DateTime.now();

  /// The completed appointments of this patient (for the Appointment dropdown).
  List<Appointment> _appointments = const [];
  bool _loadingAppointments = true;

  /// The id of the chosen appointment, or '' when the notes are not linked to one.
  String _appointmentId = '';

  /// True while the notes are being saved (the button shows a spinner).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  /// Loads this patient's completed appointments for the Appointment dropdown.
  /// If they cannot be loaded, the doctor can still write unlinked notes.
  Future<void> _loadAppointments() async {
    try {
      final all = await AppointmentService.instance.fetchAppointments();
      final now = DateTime.now();
      // Done appointments, or confirmed ones whose time has already passed.
      final mine = all.where((a) {
        if (a.patientId != widget.patient.id) return false;
        return a.status == AppointmentStatus.done ||
            (a.status == AppointmentStatus.confirmed && a.dateTime.isBefore(now));
      }).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      if (!mounted) return;
      setState(() {
        _appointments = mine;
        _loadingAppointments = false;
      });
    } on AppointmentException {
      if (!mounted) return;
      setState(() => _loadingAppointments = false);
    }
  }

  /// An appointment was chosen (or "Not linked"): fill in its date and department.
  void _onAppointmentChanged(String? id) {
    final value = id ?? '';
    setState(() {
      _appointmentId = value;
      if (value.isEmpty) return;

      final appointment = _appointments.firstWhere((a) => a.id == value);
      final now = DateTime.now();
      _date = appointment.dateTime.isAfter(now) ? now : appointment.dateTime;
      if (!_departments.contains(appointment.specialty)) {
        _departments = [..._departments, appointment.specialty];
      }
      _department = appointment.specialty;
    });
  }

  /// Opens the calendar and stores the chosen date. A visit cannot be in the future.
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = today.subtract(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      // An appointment older than a year would be outside the calendar.
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Checks the form, saves the notes, shows the confirmation popup, then
  /// tells the Patients tab we are done.
  Future<void> _save() async {
    // Run every validator; stop if any field shows an error.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await PatientsService.instance.addConsultationNote(
        widget.patient.id,
        department: _department,
        date: _date,
        appointmentId: _appointmentId,
        diagnosis: _diagnosisController.text.trim(),
        treatment: _treatmentController.text.trim(),
      );
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() => _saving = false);

      // Confirmation popup: the doctor must tap OK.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PrescriptionAddedDialog(message: 'Consultation notes saved successfully'),
      );
      if (!mounted) return;
      widget.onSaved();
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header: back arrow + title, then a thin divider
          RecordsHeader(
            title: 'Add Consultation Notes',
            onBack: widget.onBack,
            backTooltip: 'Back to patient details',
          ),

          // The form, centered with a max width
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: _buildFields(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Who it is for, the four field cards and the Save button.
  List<Widget> _buildFields() {
    const gap = SizedBox(height: AppSpacing.md);

    return [
      Text(
        'Consultation notes for ${widget.patient.name}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      ),
      gap,

      // Appointment (optional): link the notes to a completed appointment
      _fieldCard(
        label: 'Appointment (optional)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _appointmentId,
              isExpanded: true,
              decoration: AppTheme.inputDecoration(hint: 'Choose an appointment'),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text('Not linked to an appointment', style: _itemStyle),
                ),
                for (final appointment in _appointments)
                  DropdownMenuItem(
                    value: appointment.id,
                    child: Text(
                      '${formatLongDate(appointment.dateTime)} - ${appointment.specialty}',
                      style: _itemStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _loadingAppointments ? null : _onAppointmentChanged,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _loadingAppointments
                  ? 'Loading appointments...'
                  : _appointments.isEmpty
                      ? 'No completed appointments found for this patient.'
                      : 'Choosing one fills in the date and department.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      gap,

      // Department
      _fieldCard(
        label: 'Department',
        child: DropdownButtonFormField<String>(
          value: _department,
          isExpanded: true,
          decoration: AppTheme.inputDecoration(hint: 'Choose a department'),
          items: [
            for (final name in _departments)
              DropdownMenuItem(value: name, child: Text(name, style: _itemStyle)),
          ],
          onChanged: (value) => setState(() => _department = value ?? _department),
          validator: (value) => value == null ? 'Please choose a department' : null,
        ),
      ),
      gap,

      // Date of visit: tap to open the calendar
      _fieldCard(
        label: 'Date of Visit',
        child: Semantics(
          button: true,
          label: 'Date of visit, ${formatLongDate(_date)}. Tap to change.',
          child: InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: AppTheme.inputDecoration(hint: '').copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(formatLongDate(_date), style: _itemStyle),
            ),
          ),
        ),
      ),
      gap,

      // Assessment / Diagnosis (required)
      _fieldCard(
        label: 'Assessment / Diagnosis',
        child: TextFormField(
          controller: _diagnosisController,
          maxLength: 500,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(hint: 'e.g. Cough, sore throat and mild fever'),
          validator: _requiredNote('Please write the assessment or diagnosis'),
        ),
      ),
      gap,

      // Treatment / Recommendations (required)
      _fieldCard(
        label: 'Treatment / Recommendations',
        child: TextFormField(
          controller: _treatmentController,
          maxLength: 500,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(hint: 'e.g. Rest, drink fluids and take the prescribed medicine'),
          validator: _requiredNote('Please write the treatment or recommendations'),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      // Save
      H360Button(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
    ];
  }

  /// A validator for the two note fields: it cannot be empty or only a few letters.
  String? Function(String?) _requiredNote(String emptyMessage) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return emptyMessage;
      if (text.length < 5) return 'Please write at least a few words';
      return null;
    };
  }

  /// Text style of the choices in the dropdown and the date (above the minimum of 14).
  TextStyle get _itemStyle => TextStyle(fontSize: 15, color: AppColors.textPrimary);

  /// A card with a bold label on top and the field underneath.
  Widget _fieldCard({required String label, required Widget child}) {
    return H360Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
