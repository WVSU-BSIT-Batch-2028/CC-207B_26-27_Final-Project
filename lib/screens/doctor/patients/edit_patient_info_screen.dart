// Edit Patient Info (doctor side, inside the "Patients" tab).
//
// This is where a patient's age, sex, contact number, main condition,
// allergies, immunizations and medical history COME FROM. The doctor fills
// them in (the Firestore rules let only doctors write `patientProfiles`).
//
// WHAT THE DOCTOR SEES: an "Edit Patient Info" header with a back arrow, the
// patient's name, and a form prefilled with what is already saved: Age, Sex,
// Contact Number, Main Condition, Status (Active / History), Allergies,
// Immunizations, Medical History, and a Save button.
//
// WHAT THE DOCTOR CAN DO: change any field and tap Save. Age must be a whole
// number from 0 to 120 and the phone a Philippine mobile number, so Save shows
// a message under a field that is wrong. Lists are separated by commas; the
// medical history has one condition per line, with the year in brackets.
//
// WHERE THE DATA GOES: PatientsService.savePatientProfile saves it in
// `patientProfiles/{uid}`. Patient Details, Patient Records and the Patients
// list (Active / History, condition filter) all read that document.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../models/patient.dart';
import '../../../models/patient_profile.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/h360_card.dart';
import '../../../widgets/state_views.dart';
import '../../records/widgets/records_header.dart';
import 'widgets/prescription_added_dialog.dart';

/// Doctor Edit Patient Info. [onBack] cancels; [onSaved] receives the updated
/// patient summary after the confirmation popup is closed.
class EditPatientInfoScreen extends StatefulWidget {
  const EditPatientInfoScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onSaved,
  });

  final Patient patient;
  final VoidCallback onBack;
  final ValueChanged<Patient> onSaved;

  @override
  State<EditPatientInfoScreen> createState() => _EditPatientInfoScreenState();
}

class _EditPatientInfoScreenState extends State<EditPatientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _conditionController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _immunizationsController = TextEditingController();
  final _historyController = TextEditingController();

  static const List<String> _sexOptions = ['Female', 'Male', 'Prefer not to say'];

  String? _sex;
  bool _isActive = true;

  /// Loading the saved profile first, so the form is prefilled.
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _ageController,
      _phoneController,
      _conditionController,
      _allergiesController,
      _immunizationsController,
      _historyController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Reads the saved profile and fills in the form.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p = await PatientsService.instance.fetchPatientProfile(widget.patient.id);
      if (!mounted) return;
      setState(() {
        _ageController.text = p.age?.toString() ?? '';
        _phoneController.text = p.phone;
        _conditionController.text = p.condition;
        _allergiesController.text = p.allergies.join(', ');
        _immunizationsController.text = p.immunizations.join(', ');
        _historyController.text = historyText(p.history);
        _sex = _sexOptions.contains(p.sex) ? p.sex : null;
        _isActive = p.isActive;
        _loading = false;
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  /// Checks the form, saves it, shows the confirmation, then goes back.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final age = _ageController.text.trim();
    final profile = PatientProfile(
      age: age.isEmpty ? null : int.parse(age),
      sex: _sex ?? '',
      phone: _phoneController.text.trim(),
      condition: _conditionController.text.trim(),
      isActive: _isActive,
      allergies: splitList(_allergiesController.text),
      immunizations: splitList(_immunizationsController.text),
      history: parseHistory(_historyController.text),
    );

    setState(() => _saving = true);
    try {
      final updated = await PatientsService.instance.savePatientProfile(widget.patient, profile);
      if (!mounted) return;
      setState(() => _saving = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PrescriptionAddedDialog(message: 'Patient information saved'),
      );
      if (!mounted) return;
      widget.onSaved(updated);
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
          RecordsHeader(
            title: 'Edit Patient Info',
            onBack: widget.onBack,
            backTooltip: 'Back to patient details',
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            SkeletonBox(height: 120, radius: AppRadius.md),
                            SizedBox(height: AppSpacing.md),
                            SkeletonBox(height: 120, radius: AppRadius.md),
                          ],
                        ),
                      )
                    : _loadError != null
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: ErrorState(message: _loadError!, onRetry: _load),
                          )
                        : Form(
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

  List<Widget> _buildFields() {
    const gap = SizedBox(height: AppSpacing.md);

    return [
      Text(
        'Medical information for ${widget.patient.name}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      ),
      gap,

      // Age, sex and contact number
      _fieldCard(
        label: 'Personal Details',
        child: Column(
          children: [
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: AppTheme.inputDecoration(label: 'Age (years)', hint: 'e.g. 34'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null; // optional
                final age = int.tryParse(text);
                if (age == null || age < 0 || age > 120) {
                  return 'Enter a whole number from 0 to 120';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _sex,
              isExpanded: true,
              decoration: AppTheme.inputDecoration(label: 'Sex', hint: 'Choose one'),
              items: [
                for (final option in _sexOptions)
                  DropdownMenuItem(value: option, child: Text(option, style: _itemStyle)),
              ],
              onChanged: (value) => setState(() => _sex = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: AppTheme.inputDecoration(label: 'Contact Number', hint: 'e.g. 09171234567'),
              validator: (value) => Validators.mobile(value),
            ),
          ],
        ),
      ),
      gap,

      // Main condition and status
      _fieldCard(
        label: 'Care',
        child: Column(
          children: [
            TextFormField(
              controller: _conditionController,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: AppTheme.inputDecoration(
                label: 'Main Condition',
                hint: 'e.g. Hypertension',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: Text(
                _isActive ? 'Active patient' : 'Past patient (History)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Decides whether the patient is listed under Active or History.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
      gap,

      // Allergies and immunizations
      _fieldCard(
        label: 'Allergies and Immunizations',
        child: Column(
          children: [
            TextFormField(
              controller: _allergiesController,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: AppTheme.inputDecoration(
                label: 'Allergies',
                hint: 'Separate with commas, e.g. Penicillin, Peanuts',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _immunizationsController,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: AppTheme.inputDecoration(
                label: 'Immunizations',
                hint: 'e.g. Influenza (2024), Hepatitis B',
              ),
            ),
          ],
        ),
      ),
      gap,

      // Medical history: one condition per line
      _fieldCard(
        label: 'Medical History',
        child: TextFormField(
          controller: _historyController,
          maxLines: 4,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(
            hint: 'One per line, year in brackets:\nHypertension (2019)\nAsthma (2010)',
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      H360Button(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
    ];
  }

  TextStyle get _itemStyle => TextStyle(fontSize: 15, color: AppColors.textPrimary);

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
