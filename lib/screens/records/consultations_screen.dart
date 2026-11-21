// Consultations (patient side, inside the "Records" tab).
//
// WHAT THE USER SEES: the same "Records" header and filter pills as the
// Overview, but with "Consultations" selected, and only the consultation
// cards (doctor and date), newest first.
//
// WHAT THE USER CAN DO: tap a card to open its Medical Record popup, tap "All" or the
// back arrow to return to the Overview, tap "Lab Results" to open lab
// results, pull down to refresh.
//
// WHERE THE DATA COMES FROM: RecordsService.fetchConsultations (mock for now).
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/health_record.dart';
import '../../services/records_service.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/state_views.dart';
import 'consultation_details_dialog.dart';
import 'widgets/record_card.dart';
import 'widgets/record_filter_bar.dart';
import 'widgets/records_header.dart';
import 'widgets/records_scroll_body.dart';

/// Loading states of this screen (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Patient Consultations list. [onBack] returns to Records Overview;
/// [onFilterSelected] tells the Records tab which screen a tapped pill opens.
class ConsultationsScreen extends StatefulWidget {
  const ConsultationsScreen({
    super.key,
    required this.onBack,
    required this.onFilterSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<RecordFilter> onFilterSelected;

  @override
  State<ConsultationsScreen> createState() => _ConsultationsScreenState();
}

class _ConsultationsScreenState extends State<ConsultationsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<HealthRecord> _consultations = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for the consultations and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final items = await RecordsService.instance.fetchConsultations();
      // The user may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _consultations = items;
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

  /// Opens the Medical Record popup (Consultation Details) for this card.
  void _openConsultation(HealthRecord record) {
    showConsultationDetails(context, record);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          RecordsHeader(onBack: widget.onBack, backTooltip: 'Back to all records'),
          Expanded(
            child: RecordsScrollBody(
              onRefresh: () => _load(showSkeleton: false),
              children: _buildChildren(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the list content for the current state: loading, error, empty or ready.
  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.md);

    switch (_status) {
      // Loading: skeleton placeholders shaped like the pills and cards
      case _LoadStatus.loading:
        return [
          const SkeletonBox(height: 44, width: 240, radius: 999),
          gap,
          for (var i = 0; i < 2; i++) ...[
            const SkeletonBox(height: 110, radius: AppRadius.md),
            gap,
          ],
        ];

      // Error: message + "Try again" button
      case _LoadStatus.error:
        return [ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        return [
          // Filter pills, with "Consultations" selected
          RecordFilterBar(
            selected: RecordFilter.consultations,
            onChanged: widget.onFilterSelected,
          ),
          gap,

          // Empty: no consultations yet
          if (_consultations.isEmpty)
            const EmptyState(
              icon: Icons.medical_services_outlined,
              title: 'No consultations yet',
              message: "Your doctor's notes will appear here after your first consultation.",
            ),

          // List of consultation cards (each fades in a little after the one above)
          for (var i = 0; i < _consultations.length; i++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i),
              child: RecordCard(
                record: _consultations[i],
                onTap: () => _openConsultation(_consultations[i]),
              ),
            ),
            gap,
          ],
        ];
    }
  }
}
