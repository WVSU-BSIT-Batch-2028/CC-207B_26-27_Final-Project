// Consultation Details (patient side): the "Medical Record" popup.
//
// WHAT THE USER SEES: a card floating over the dimmed Records screen with the
// visit information (doctor, department, type, date), the doctor's
// Assessment / Diagnosis, the Treatment / Recommendations, and a Close button.
//
// KNOWN LIMITATION: the prototype also has "Download Documents" links. They
// are left out on purpose (the project rules say no downloading or sharing of
// records as PDF). List it under Known Limitations / Future Enhancements.
//
// WHERE THE DATA COMES FROM: RecordsService.fetchConsultationDetail (Firestore).
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/date_format.dart';
import '../../models/consultation_detail.dart';
import '../../models/health_record.dart';
import '../../services/records_service.dart';
import '../../widgets/state_views.dart';
import 'widgets/record_popup.dart';

/// Opens the Medical Record popup for [record] (a consultation).
Future<void> showConsultationDetails(BuildContext context, HealthRecord record) {
  return showDialog<void>(
    context: context,
    builder: (_) => ConsultationDetailsDialog(recordId: record.id),
  );
}

/// Loading states of the popup (same pattern as the other screens).
enum _LoadStatus { loading, ready, error }

/// The popup itself. It loads its own data, so it needs a loading and an
/// error state too.
class ConsultationDetailsDialog extends StatefulWidget {
  const ConsultationDetailsDialog({super.key, required this.recordId});

  /// Which consultation to show.
  final String recordId;

  @override
  State<ConsultationDetailsDialog> createState() => _ConsultationDetailsDialogState();
}

class _ConsultationDetailsDialogState extends State<ConsultationDetailsDialog> {
  _LoadStatus _status = _LoadStatus.loading;
  ConsultationDetail? _detail;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for the full record and updates the popup state.
  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final detail = await RecordsService.instance.fetchConsultationDetail(widget.recordId);
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
    return RecordPopup(title: 'Medical Record', child: _buildContent());
  }

  /// The middle part for the current state: loading, error or ready.
  Widget _buildContent() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 110),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 70),
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
            // Visit Information
            const PopupSectionTitle('Visit Information'),
            const SizedBox(height: AppSpacing.sm),
            PopupInfoLine(label: 'Doctor', value: d.doctorName),
            PopupInfoLine(label: 'Department', value: d.department),
            PopupInfoLine(label: 'Type', value: d.type),
            PopupInfoLine(label: 'Date', value: formatLongDate(d.date)),
            const PopupSectionDivider(),

            // Assessment / Diagnosis
            const PopupSectionTitle('Assessment / Diagnosis'),
            const SizedBox(height: AppSpacing.sm),
            PopupBodyText(d.diagnosis),
            const PopupSectionDivider(),

            // Treatment / Recommendations
            const PopupSectionTitle('Treatment / Recommendations'),
            const SizedBox(height: AppSpacing.sm),
            PopupBodyText(d.treatment),
          ],
        );
    }
  }
}
