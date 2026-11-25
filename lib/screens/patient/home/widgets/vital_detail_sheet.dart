import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/validators.dart';
import '../../../../models/vital_sign.dart';
import '../../../../services/dashboard_service.dart';
import '../../../../widgets/h360_button.dart';
import '../../../../widgets/sparkline.dart';
import '../../../../widgets/status_chip.dart';
import 'vital_style.dart';

/// Detail sheet for one vital: trend, recent readings and an "Add a
/// reading" form. [onChanged] returns the updated vital to Home.
Future<void> showVitalDetailSheet(
  BuildContext context, {
  required VitalSign vital,
  required ValueChanged<VitalSign> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    constraints: const BoxConstraints(maxWidth: AppSizes.sheet),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _VitalDetailSheet(initial: vital, onChanged: onChanged),
  );
}

/// The sheet's content; keeps the vital up to date as readings are added.
class _VitalDetailSheet extends StatefulWidget {
  const _VitalDetailSheet({required this.initial, required this.onChanged});

  final VitalSign initial;
  final ValueChanged<VitalSign> onChanged;

  @override
  State<_VitalDetailSheet> createState() => _VitalDetailSheetState();
}

class _VitalDetailSheetState extends State<_VitalDetailSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();

  late VitalSign _vital = widget.initial;
  bool _saving = false;

  bool get _isPressure => _vital.type == VitalType.bloodPressure;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  // Form labels and limits

  String get _firstLabel {
    switch (_vital.type) {
      case VitalType.heartRate:
        return 'Heart rate (bpm)';
      case VitalType.bloodPressure:
        return 'Systolic (top number)';
      case VitalType.weight:
        return 'Weight (kg)';
      case VitalType.sleep:
        return 'Hours slept (e.g. 6.5)';
    }
  }

  String? _validateFirst(String? value) {
    switch (_vital.type) {
      case VitalType.heartRate:
        return Validators.number(value, label: 'heart rate', min: 30, max: 220, wholeNumber: true);
      case VitalType.bloodPressure:
        return Validators.number(value, label: 'systolic value', min: 70, max: 250, wholeNumber: true);
      case VitalType.weight:
        return Validators.number(value, label: 'weight', min: 20, max: 300);
      case VitalType.sleep:
        return Validators.number(value, label: 'number of hours', min: 0, max: 24);
    }
  }

  String? _validateSecond(String? value) {
    final base = Validators.number(value, label: 'diastolic value', min: 40, max: 150, wholeNumber: true);
    if (base != null) return base;
    final systolic = double.tryParse(_first.text.trim());
    final diastolic = double.tryParse((value ?? '').trim());
    if (systolic != null && diastolic != null && diastolic >= systolic) {
      return 'Diastolic must be lower than systolic.';
    }
    return null;
  }

  /// Validates, saves the reading and updates the trend.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final reading = VitalReading(
      date: DateTime.now(),
      value: double.parse(_first.text.trim()),
      secondary: _isPressure ? double.parse(_second.text.trim()) : null,
      source: ReadingSource.you,
    );

    setState(() => _saving = true);
    try {
      await DashboardService.instance.addReading(_vital.type, reading);
    } on DashboardException catch (e) {
      // Save failed: keep the form filled so they can retry.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;

    final updated = _vital.withReading(reading);
    setState(() {
      _vital = updated;
      _saving = false;
    });
    _first.clear();
    _second.clear();
    _formKey.currentState?.reset();
    widget.onChanged(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading saved. Your trend is updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _vital.type.color;
    final normal = _vital.status == VitalStatus.normal;
    final hasReadings = _vital.hasReadings;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),

            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(_vital.type.icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _vital.label,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Latest value + status
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _vital.value,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(width: 6),
                Text(_vital.unit, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            if (hasReadings)
              StatusChip(
                label: normal ? 'Usual range' : 'Worth a look',
                color: normal ? AppColors.success : AppColors.warning,
                icon: normal ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
              ),
            const SizedBox(height: 14),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      !hasReadings
                          ? 'No readings yet. Add your first one below. Your doctor will see it in your record.'
                          : 'Add a new reading below whenever you measure. Your doctor can see your readings in your record.',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Trend and history once there are readings.
            if (hasReadings) ...[
              _sectionTitle('Last 7 readings'),
              _trend(color),
              const SizedBox(height: 20),

              _sectionTitle('Recent readings'),
              for (final r in _vital.recent.reversed) _ReadingRow(vital: _vital, reading: r),
              const SizedBox(height: 20),
            ],

            _sectionTitle('Add a reading'),
            _form(),
            const SizedBox(height: 16),
            Text(
              'General ranges only, not a diagnosis. Talk to your doctor about your numbers.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
      );

  /// Trend line, weekday labels and lowest / average / highest.
  Widget _trend(Color color) {
    final values = _vital.trend;
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final average = values.reduce((a, b) => a + b) / values.length;

    Widget stat(String label, double v) => Expanded(
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(
                vitalStatText(_vital.type, v),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Sparkline(values: values, color: color, height: 110),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final r in _vital.recent)
                Text(weekdayShort(r.date), style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Lowest', lowest),
              stat('Average', average),
              stat('Highest', highest),
            ],
          ),
          if (_isPressure)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'The trend shows the systolic (top) number.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  /// The "Add a reading" form.
  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _first,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _validateFirst,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: AppTheme.inputDecoration(label: _firstLabel),
          ),
          if (_isPressure) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _second,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateSecond,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: AppTheme.inputDecoration(label: 'Diastolic (bottom number)'),
            ),
          ],
          const SizedBox(height: 14),
          H360Button(label: 'Save reading', icon: Icons.add_rounded, isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

/// One line in Recent readings: date and value.
class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.vital, required this.reading});

  final VitalSign vital;
  final VitalReading reading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Date on the left, value on the right edge.
          Expanded(
            child: Text(
              formatShortDate(reading.date),
              style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${vitalValueText(vital.type, reading)} ${vital.unit}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}
