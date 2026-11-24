// Add Lab Result (doctor side, inside the "Patients" tab).
//
// This is where lab results COME FROM: the doctor enters the numbers from the
// laboratory's report. The patient then reads them in Records > Lab Results,
// and the doctor in Patient Records > Lab Results.
//
// WHAT THE DOCTOR SEES: an "Add Lab Result" header with a back arrow, who the
// result is for, and a form: Test, Date of Test, one field per measured value
// (with its unit and normal range), Overall Result, optional Doctor's Notes,
// and a Save button.
//
// WHAT THE DOCTOR CAN DO: choose a test (the value fields change to match it),
// type the numbers and tap Save. Every value must be a number, so Save shows a
// message under any field that is empty or not a number. High / Low flags are
// worked out from the normal range automatically. Saved results cannot be
// edited (they are "view only").
//
// WHERE THE DATA GOES: PatientsService.addLabResult saves it in the
// `labResults` collection of Firestore with the doctor's name as "Requested by".
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/lab_result_detail.dart';
import '../../../models/lab_test_option.dart';
import '../../../models/patient.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/h360_button.dart';
import '../../../widgets/h360_card.dart';
import '../../records/widgets/records_header.dart';
import 'widgets/prescription_added_dialog.dart';

/// Doctor Add Lab Result. [onBack] cancels and returns to the patient's lab
/// results; [onSaved] is called after the confirmation popup is closed.
class AddLabResultScreen extends StatefulWidget {
  const AddLabResultScreen({
    super.key,
    required this.patient,
    required this.onBack,
    required this.onSaved,
  });

  /// The patient the result is for.
  final Patient patient;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  State<AddLabResultScreen> createState() => _AddLabResultScreenState();
}

class _AddLabResultScreenState extends State<AddLabResultScreen> {
  /// Used to run every field's validator when Save is tapped.
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _overallController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  /// One text field per measured value of the chosen test.
  List<TextEditingController> _valueControllers = const [];

  /// The chosen test (null until the doctor picks one).
  LabTestOption? _test;
  DateTime _date = DateTime.now();

  /// True while the result is being saved (the button shows a spinner).
  bool _saving = false;

  @override
  void dispose() {
    _overallController.dispose();
    _notesController.dispose();
    for (final c in _valueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// A test was chosen: make one empty field for each of its values.
  void _onTestChanged(LabTestOption? test) {
    for (final c in _valueControllers) {
      c.dispose();
    }
    setState(() {
      _test = test;
      _valueControllers = [
        for (var i = 0; i < (test?.measures.length ?? 0); i++) TextEditingController(),
      ];
    });
  }

  /// Opens the calendar. A test date cannot be in the future.
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// The values as the maps saved in Firestore. The flag (normal / low /
  /// high) comes from LabValue, the same code that shows it later.
  List<Map<String, dynamic>> _values() {
    final test = _test!;
    return [
      for (var i = 0; i < test.measures.length; i++)
        () {
          final m = test.measures[i];
          final value = double.parse(_valueControllers[i].text.trim());
          final flag = LabValue.fromMap({'value': value, 'range': m.range}).flag;
          return <String, dynamic>{
            'name': m.name,
            'value': value,
            'unit': m.unit,
            'range': m.range,
            'flag': flag.name,
          };
        }(),
    ];
  }

  /// Checks the form, saves the result, shows the confirmation popup, then
  /// tells the Patients tab we are done.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await PatientsService.instance.addLabResult(
        widget.patient.id,
        testName: _test!.name,
        date: _date,
        values: _values(),
        overallResult: _overallController.text.trim(),
        doctorNotes: _notesController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PrescriptionAddedDialog(message: 'Lab result saved successfully'),
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
          RecordsHeader(
            title: 'Add Lab Result',
            onBack: widget.onBack,
            backTooltip: 'Back to lab results',
          ),
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

  /// Who it is for, the test, the date, the values, the summary and Save.
  List<Widget> _buildFields() {
    const gap = SizedBox(height: AppSpacing.md);
    final test = _test;

    return [
      Text(
        'Lab result for ${widget.patient.name}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      ),
      gap,

      // Test
      _fieldCard(
        label: 'Test',
        child: DropdownButtonFormField<LabTestOption>(
          value: _test,
          isExpanded: true,
          decoration: AppTheme.inputDecoration(hint: 'Choose a test'),
          items: [
            for (final option in kLabTestCatalog)
              DropdownMenuItem(value: option, child: Text(option.name, style: _itemStyle)),
          ],
          onChanged: _onTestChanged,
          validator: (value) => value == null ? 'Please choose a test' : null,
        ),
      ),
      gap,

      // Date of test
      _fieldCard(
        label: 'Date of Test',
        child: Semantics(
          button: true,
          label: 'Date of test, ${formatLongDate(_date)}. Tap to change.',
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

      // One field per measured value (only after a test is chosen)
      if (test != null) ...[
        _fieldCard(
          label: 'Results',
          child: Column(
            children: [
              for (var i = 0; i < test.measures.length; i++) ...[
                TextFormField(
                  // The key makes a fresh field when the test changes.
                  key: ValueKey('${test.name}-$i'),
                  controller: _valueControllers[i],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: AppTheme.inputDecoration(hint: 'Value').copyWith(
                    labelText: test.measures[i].unit.isEmpty
                        ? test.measures[i].name
                        : '${test.measures[i].name} (${test.measures[i].unit})',
                    helperText: 'Normal range: ${test.measures[i].range}',
                  ),
                  validator: _number,
                ),
                if (i < test.measures.length - 1) const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        gap,
      ],

      // Overall result (required)
      _fieldCard(
        label: 'Overall Result',
        child: TextFormField(
          controller: _overallController,
          maxLength: 200,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(hint: 'e.g. All values within normal range'),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Please write a short summary';
            if (text.length < 5) return 'Please write at least a few words';
            return null;
          },
        ),
      ),
      gap,

      // Doctor's notes (optional)
      _fieldCard(
        label: "Doctor's Notes (optional)",
        child: TextFormField(
          controller: _notesController,
          maxLength: 500,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppTheme.inputDecoration(hint: 'e.g. Repeat the test in 3 months'),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      H360Button(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
    ];
  }

  /// A value must be a number (0 or more).
  String? _number(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the value';
    final number = double.tryParse(text);
    if (number == null) return 'Please enter a number, e.g. 13.5';
    if (number < 0) return 'The value cannot be negative';
    return null;
  }

  /// Text style of the dropdown choices and the date (above the minimum of 14).
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
