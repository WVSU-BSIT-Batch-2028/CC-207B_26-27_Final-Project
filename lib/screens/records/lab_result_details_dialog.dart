// Lab Result Details (patient side): the "Lab Results" popup.
//
// WHAT THE USER SEES: a card floating over the dimmed Records screen with the
// test name, who it is for and who requested it, a results table (test,
// result, reference range), the overall result, the doctor's notes and a
// Close button.
//
// ABNORMAL VALUES: a value outside its reference range gets a tinted row AND a
// "High" or "Low" label with an arrow, so it is never shown by colour alone.
//
// KNOWN LIMITATION: the prototype also has a "View Full Laboratory Report"
// link. It is left out on purpose (the project rules say no downloading or
// sharing of lab results as PDF). List it under Known Limitations.
//
// WHERE THE DATA COMES FROM: RecordsService.fetchLabResultDetail (mock).
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_format.dart';
import '../../models/health_record.dart';
import '../../models/lab_result_detail.dart';
import '../../services/records_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import 'widgets/record_popup.dart';

/// Opens the Lab Results popup for [record] (a lab result).
Future<void> showLabResultDetails(BuildContext context, HealthRecord record) {
  return showDialog<void>(
    context: context,
    builder: (_) => LabResultDetailsDialog(recordId: record.id),
  );
}

/// Loading states of the popup (same pattern as the other screens).
enum _LoadStatus { loading, ready, error }

/// The popup itself. It loads its own data, so it needs a loading and an
/// error state too.
class LabResultDetailsDialog extends StatefulWidget {
  const LabResultDetailsDialog({super.key, required this.recordId});

  /// Which lab result to show.
  final String recordId;

  @override
  State<LabResultDetailsDialog> createState() => _LabResultDetailsDialogState();
}

class _LabResultDetailsDialogState extends State<LabResultDetailsDialog> {
  _LoadStatus _status = _LoadStatus.loading;
  LabResultDetail? _detail;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for the full lab result and updates the popup state.
  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final detail = await RecordsService.instance.fetchLabResultDetail(widget.recordId);
      // The user may have closed the popup while we waited.
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _status = _LoadStatus.ready;
      });
    } on RecordsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // RecordPopup draws the card, title, scrolling and Close button.
    return RecordPopup(title: 'Lab Results', child: _buildContent());
  }

  /// The middle part for the current state: loading, error or ready.
  Widget _buildContent() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 100),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 160),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 70),
          ],
        );

      case _LoadStatus.error:
        return ErrorState(message: _error, onRetry: _load);

      case _LoadStatus.ready:
        final d = _detail!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Test name
            PopupSectionTitle(d.testName),
            const SizedBox(height: AppSpacing.md),

            // Who it is for, who asked for it, status and date
            PopupInfoLine(label: 'Patient', value: d.patientName),
            PopupInfoLine(label: 'Requested by', value: d.requestedBy),
            PopupInfoLine(label: 'Status', value: d.status),
            PopupInfoLine(label: 'Date', value: formatLongDate(d.date)),
            const PopupSectionDivider(),

            // Results table
            const PopupSectionTitle('Results'),
            const SizedBox(height: AppSpacing.sm),
            _ResultsTable(values: d.results),
            const PopupSectionDivider(),

            // Overall result and the doctor's notes
            _LabeledParagraph(label: 'Overall Result', text: d.overallResult),
            const SizedBox(height: AppSpacing.md),
            _LabeledParagraph(label: "Doctor's Notes", text: d.doctorNotes),
          ],
        );
    }
  }
}

/// The results table: a header row, then one row per measured value.
/// Built from Rows and Expanded (not a Table) so long text wraps at large text sizes.
class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.values});

  final List<LabValue> values;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: Text('Test', style: headerStyle)),
              Expanded(flex: 5, child: Text('Result', style: headerStyle)),
              Expanded(flex: 4, child: Text('Reference Range', style: headerStyle)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // One row per value
        for (final value in values) ...[
          _ResultRow(value: value),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

/// One row of the table. An abnormal value gets a tinted background and a
/// High / Low chip under the number.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.value});

  final LabValue value;

  /// Red for high, amber for low.
  Color get _flagColor => value.flag == LabFlag.high ? AppColors.danger : AppColors.warning;

  /// Arrow up for high, arrow down for low.
  IconData get _flagIcon =>
      value.flag == LabFlag.high ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

  @override
  Widget build(BuildContext context) {
    final isAbnormal = value.flag != LabFlag.normal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isAbnormal ? _flagColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Test name
          Expanded(
            flex: 5,
            child: Text(
              value.name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),

          // Result (+ High / Low label if abnormal)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.resultText,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (isAbnormal) ...[
                  const SizedBox(height: AppSpacing.xs),
                  StatusChip(label: value.flag.label, color: _flagColor, icon: _flagIcon),
                ],
              ],
            ),
          ),

          // Reference range
          Expanded(
            flex: 4,
            child: Text(
              value.rangeText,
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bold label with a paragraph under it (Overall Result, Doctor's Notes).
class _LabeledParagraph extends StatelessWidget {
  const _LabeledParagraph({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        const SizedBox(height: AppSpacing.xs),
        PopupBodyText(text),
      ],
    );
  }
}
