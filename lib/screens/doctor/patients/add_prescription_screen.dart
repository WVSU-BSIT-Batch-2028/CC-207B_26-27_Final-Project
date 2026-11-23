// Add Prescription (doctor side, inside the "Patients" tab). After saving it
// shows the "Prescription added successfully" popup (the Prescription Added
// screen of the prototype).
//
// WHAT THE DOCTOR SEES: an "Add Prescription" header with a back arrow, who
// the prescription is for, and a form: Medicine Name, Dosage, Frequency,
// Duration, Start Date, optional Notes, and a Save button.
//
// WHAT THE DOCTOR CAN DO: fill in the form and tap Save. Every dropdown is
// required, so Save shows a message under any field left empty. The Dosage
// list depends on the medicine. When it is saved, the doctor sees the
// confirmation popup and, after OK, goes back to the patient's prescriptions.
//
// WHERE THE DATA GOES: PatientsService.addPrescription saves it on the device
// (shared_preferences), so it is still there after the app restarts.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/medicine_option.dart';
import '../../../models/patient.dart';
import '../../../models/doctor_prescription.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/h360_card.dart';
import '../../records/widgets/records_header.dart';
import 'widgets/prescription_added_dialog.dart';

/// Doctor Add Prescription. [onBack] cancels and returns to the patient's
/// prescriptions; [onSaved] is called after the confirmation popup is closed.
class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onSaved,
  });

  /// The patient the prescription is for.
  final Patient patient;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  /// Used to run every field's validator when Save is tapped.
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  // What the doctor has chosen so far (null = not chosen yet).
  MedicineOption? _medicine;
  String? _dosage;
  int? _timesPerDay;
  int? _durationDays;
  DateTime _startDate = DateTime.now();

  /// True while the prescription is being saved (the button shows a spinner).
  bool _saving = false;

  /// The choices for Frequency: times per day -> text in the dropdown.
  static const Map<int, String> _frequencies = {
    1: 'Take as needed',
    2: 'Once a day',
    3: 'Twice a day',
    4: '3 times a day',
    5: '4 times a day',
  };

  /// The choices for Duration, in days.
  static const List<int> _durations = [3, 5, 7, 10, 14, 30];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Opens the calendar and stores the chosen start date.
  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// Checks the form, saves the prescription, shows the confirmation popup,
  /// then tells the Patients tab we are done.
  Future<void> _save() async {
    // Run every validator; stop if any field shows an error.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final medicine = _medicine!;
    final days = _durationDays!;
    final notes = _notesController.text.trim();

    setState(() => _saving = true);
    try {
      final prescription = DoctorPrescription(
        id: 'rx-${DateTime.now().millisecondsSinceEpoch}',
        medicineName: medicine.name,
        dosage: _dosage!,
        form: medicine.form,
        timesPerDay: _timesPerDay!,
        durationDays: days,
        startDate: _startDate,
        // The patient can refill when the course ends.
        refillDate: _startDate.add(Duration(days: days)),
        notes: notes.isEmpty ? null : notes,
      );
      await PatientsService.instance
          .addPrescription(widget.patient.id, prescription);
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() => _saving = false);

      // Confirmation popup: the doctor must tap OK.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PrescriptionAddedDialog(),
      );
      if (!mounted) return;
      widget.onSaved();
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
            title: 'Add Prescription',
            onBack: widget.onBack,
            backTooltip: 'Back to prescriptions',
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

  /// Who it is for, the five field cards, the notes field and the Save button.
  List<Widget> _buildFields() {
    const gap = SizedBox(height: AppSpacing.md);

    return [
      Text(
        'Prescription for ${widget.patient.name}',
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted),
      ),
      gap,

      // Medicine Name. Choosing a new medicine clears the dosage.
      _fieldCard(
        label: 'Medicine Name',
        child: DropdownButtonFormField<MedicineOption>(
          value: _medicine,
          isExpanded: true,
          decoration: AppTheme.inputDecoration(hint: 'Choose a medicine'),
          items: [
            for (final option in kMedicineCatalog)
              DropdownMenuItem(
                  value: option, child: Text(option.name, style: _itemStyle)),
          ],
          onChanged: (value) => setState(() {
            _medicine = value;
            _dosage = null;
          }),
          validator: (value) =>
              value == null ? 'Please choose a medicine' : null,
        ),
      ),
      gap,

      // Dosage: only the doses of the chosen medicine. The key rebuilds the
      // field when the medicine changes, so an old dosage is never kept.
      _fieldCard(
        label: 'Dosage',
        child: DropdownButtonFormField<String>(
          key: ValueKey(_medicine?.name),
          value: _dosage,
          isExpanded: true,
          decoration: AppTheme.inputDecoration(
            hint: _medicine == null
                ? 'Choose a medicine first'
                : 'Choose a dosage',
          ),
          items: [
            for (final dose in _medicine?.dosages ?? const <String>[])
              DropdownMenuItem(
                  value: dose, child: Text(dose, style: _itemStyle)),
          ],
          // Disabled until a medicine is chosen.
          onChanged: _medicine == null
              ? null
              : (value) => setState(() => _dosage = value),
          validator: (value) => value == null ? 'Please choose a dosage' : null,
        ),
      ),
      gap,

      // Frequency
      _fieldCard(
        label: 'Frequency',
        child: DropdownButtonFormField<int>(
          value: _timesPerDay,
          isExpanded: true,
          decoration: AppTheme.inputDecoration(hint: 'Choose how often'),
          items: [
            for (final entry in _frequencies.entries)
              DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, style: _itemStyle)),
          ],
          onChanged: (value) => setState(() => _timesPerDay = value),
          validator: (value) =>
              value == null ? 'Please choose how often' : null,
        ),
      ),
      gap,

      // Duration
      _fieldCard(
        label: 'Duration',
        child: DropdownButtonFormField<int>(
          value: _durationDays,
          isExpanded: true,
          decoration: AppTheme.inputDecoration(hint: 'Choose how many days'),
          items: [
            for (final days in _durations)
              DropdownMenuItem(
                  value: days, child: Text('$days days', style: _itemStyle)),
          ],
          onChanged: (value) => setState(() => _durationDays = value),
          validator: (value) =>
              value == null ? 'Please choose how many days' : null,
        ),
      ),
      gap,

      // Start Date: tap to open the calendar
      _fieldCard(
        label: 'Start Date',
        child: Semantics(
          button: true,
          label: 'Start date, ${formatLongDate(_startDate)}. Tap to change.',
          child: InkWell(
            onTap: _pickStartDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: AppTheme.inputDecoration(hint: '').copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(formatLongDate(_startDate), style: _itemStyle),
            ),
          ),
        ),
      ),
      gap,

      // Notes (optional, up to 200 characters)
      _fieldCard(
        label: 'Notes / Instructions (optional)',
        child: TextFormField(
          controller: _notesController,
          maxLength: 200,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(hint: 'e.g. Take after meals'),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      // Save
      H360Button(
          label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
    ];
  }

  /// Text style of the choices in the dropdowns and the date (above the minimum of 14).
  TextStyle get _itemStyle =>
      TextStyle(fontSize: 15, color: AppColors.textPrimary);

  /// A card with a bold label on top and the field underneath, as in the prototype.
  Widget _fieldCard({required String label, required Widget child}) {
    return H360Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.navy),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
