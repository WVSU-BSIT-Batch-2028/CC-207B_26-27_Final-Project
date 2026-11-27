// The "Records" tab of the patient app.
//
// This widget is only a HOST: it decides which Records screen is visible
// (Overview, Consultations or Lab Results). The bottom navigation bar belongs
// to PatientShell, so it stays visible on every screen, as in the prototype.
import 'package:flutter/material.dart';

import 'consultations_screen.dart';
import 'lab_results_screen.dart';
import 'records_overview_screen.dart';
import 'widgets/record_filter_bar.dart';

/// Patient Records tab. [onBack] switches the app to the Home tab.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  /// Which pill (and so which screen) is active. The enum order is
  /// All, Consultations, Lab Results, the same as the IndexedStack children below.
  RecordFilter _current = RecordFilter.all;

  /// Switches the visible screen to the one that matches [filter].
  void _show(RecordFilter filter) => setState(() => _current = filter);

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps all three screens alive, so going back to the Overview
    // keeps its loaded data (no reload, no skeleton).
    return IndexedStack(
      index: _current.index,
      children: [
        RecordsOverviewScreen(onBack: widget.onBack, onFilterSelected: _show),
        ConsultationsScreen(onBack: () => _show(RecordFilter.all), onFilterSelected: _show),
        LabResultsScreen(onBack: () => _show(RecordFilter.all), onFilterSelected: _show),
      ],
    );
  }
}
