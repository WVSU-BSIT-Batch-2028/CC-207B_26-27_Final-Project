// Records Overview (patient side, "Records" tab).
//
// WHAT THE USER SEES: a "Records" header with a back arrow, three filter pills
// (All / Consultations / Lab Results) and the list of every record, newest
// first. Each card shows an icon, the title, the doctor or test name, the
// date and "View". "All" is the selected pill on this screen.
//
// WHAT THE USER CAN DO: tap "Consultations" or "Lab Results" to open that
// screen, tap a card to open its details, pull down to refresh, tap the back
// arrow to return to Home.
//
// WHERE THE DATA COMES FROM: RecordsService (mock data for now).
//
// SHARED WIDGETS USED: H360Card (inside RecordCard), SkeletonBox, EmptyState,
// ErrorState, FadeSlideIn, RecordsHeader, RecordsScrollBody.
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/health_record.dart';
import '../../services/records_service.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/state_views.dart';
import 'consultation_details_dialog.dart';
import 'lab_result_details_dialog.dart';
import 'widgets/record_card.dart';
import 'widgets/record_filter_bar.dart';
import 'widgets/records_header.dart';
import 'widgets/records_scroll_body.dart';

/// The three states the screen can be in while it loads data
/// (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Patient Records Overview. [onBack] switches the bottom-nav tab to Home,
/// because this screen is a tab, not a pushed page. [onFilterSelected] tells
/// the Records tab (RecordsScreen) which screen to show when a pill is tapped.
class RecordsOverviewScreen extends StatefulWidget {
  const RecordsOverviewScreen({
    super.key,
    required this.onBack,
    required this.onFilterSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<RecordFilter> onFilterSelected;

  @override
  State<RecordsOverviewScreen> createState() => _RecordsOverviewScreenState();
}

class _RecordsOverviewScreenState extends State<RecordsOverviewScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<HealthRecord> _records = const [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the service for the records and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final records = await RecordsService.instance.fetchRecords();
      // The user may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _records = records;
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

  /// Opens the matching popup: Medical Record for a consultation,
  /// Lab Results for a lab result.
  void _openRecord(HealthRecord record) {
    if (record.type == RecordType.consultation) {
      showConsultationDetails(context, record);
    } else {
      showLabResultDetails(context, record);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header: back arrow + title, then a thin divider (as in the prototype)
          RecordsHeader(onBack: widget.onBack, backTooltip: 'Back to Home'),

          // Body: centered, max width, pull-to-refresh (shared with the other Records screens)
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
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 110, radius: AppRadius.md),
            gap,
          ],
        ];

      // Error: message + "Try again" button
      case _LoadStatus.error:
        return [ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        // Empty: the patient has no records at all
        if (_records.isEmpty) {
          return [
            const EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No records yet',
              message: 'Your consultations and lab results will appear here after your visits.',
            ),
          ];
        }

        return [
          // Filter pills, with "All" selected
          RecordFilterBar(
            selected: RecordFilter.all,
            onChanged: widget.onFilterSelected,
          ),
          gap,

          // List of record cards (each fades in a little after the one above)
          for (var i = 0; i < _records.length; i++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i),
              child: RecordCard(
                record: _records[i],
                onTap: () => _openRecord(_records[i]),
              ),
            ),
            gap,
          ],
        ];
    }
  }
}
