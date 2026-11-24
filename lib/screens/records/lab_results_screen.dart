// Laboratory Results (patient side, inside the "Records" tab).
//
// WHAT THE USER SEES: the same "Records" header and filter pills as the other
// Records screens, but with "Lab Results" selected, and only the lab result
// cards (test name and date), newest first.
//
// WHAT THE USER CAN DO: tap a card to open its Lab Results popup, tap "All" or the
// back arrow to return to the Overview, tap "Consultations" to open the
// consultations, pull down to refresh.
//
// WHERE THE DATA COMES FROM: RecordsService.fetchLabResults (Firestore).
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/health_record.dart';
import '../../services/records_service.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/state_views.dart';
import 'lab_result_details_dialog.dart';
import 'widgets/record_card.dart';
import 'widgets/record_filter_bar.dart';
import 'widgets/records_header.dart';
import 'widgets/records_scroll_body.dart';

/// Loading states of this screen (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Patient Laboratory Results list. [onBack] returns to Records Overview;
/// [onFilterSelected] tells the Records tab which screen a tapped pill opens.
class LabResultsScreen extends StatefulWidget {
  const LabResultsScreen({
    super.key,
    required this.onBack,
    required this.onFilterSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<RecordFilter> onFilterSelected;

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<HealthRecord> _labResults = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for the lab results and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final items = await RecordsService.instance.fetchLabResults();
      // The user may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _labResults = items;
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

  /// Opens the Lab Results popup (Lab Result Details) for this card.
  void _openLabResult(HealthRecord record) {
    showLabResultDetails(context, record);
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
          // Filter pills, with "Lab Results" selected
          RecordFilterBar(
            selected: RecordFilter.labResults,
            onChanged: widget.onFilterSelected,
          ),
          gap,

          // Empty: no lab results yet
          if (_labResults.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No lab results yet',
              message: 'Your lab results will appear here once your tests are done.',
            ),

          // List of lab result cards (each fades in a little after the one above)
          for (var i = 0; i < _labResults.length; i++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i),
              child: RecordCard(
                record: _labResults[i],
                onTap: () => _openLabResult(_labResults[i]),
              ),
            ),
            gap,
          ],
        ];
    }
  }
}
