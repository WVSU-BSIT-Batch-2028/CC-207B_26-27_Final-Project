// Patients page (doctor side, "Patients" tab).
//
// WHAT THE DOCTOR SEES: a "Patients" header with a back arrow, two pills
// (Active / History), a search bar, condition filter chips and a list of
// patient cards (name, condition, last visit), most recent visit first.
//
// WHAT THE DOCTOR CAN DO: switch between Active and History, search by name
// or condition, filter by condition, tap a patient to open their details,
// pull down to refresh, tap the back arrow to return to Home.
//
// WHERE THE DATA COMES FROM: PatientsService (mock data for now).
//
// SHARED WIDGETS USED: PatientCard, RecordsHeader, RecordsScrollBody,
// SkeletonBox, EmptyState, ErrorState, FadeSlideIn.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/patient.dart';
import '../../../services/patients_service.dart';
import '../../../widgets/fade_slide_in.dart';
import '../../../widgets/state_views.dart';
import '../../records/widgets/records_header.dart';
import '../../records/widgets/records_scroll_body.dart';
import 'widgets/patient_card.dart';

/// The three states the screen can be in while it loads data
/// (same pattern as HomeScreen).
enum _LoadStatus { loading, ready, error }

/// Doctor Patients page. [onBack] switches the bottom-nav tab to Home,
/// because this screen is a tab, not a pushed page. [onOpenPatient] tells the
/// Patients tab (DoctorPatientsTab) which patient was tapped.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key, required this.onBack, required this.onOpenPatient});

  final VoidCallback onBack;
  final ValueChanged<Patient> onOpenPatient;

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<Patient> _patients = const [];
  String _error = '';

  /// true = "Active" pill, false = "History" pill.
  bool _showActive = true;

  /// Selected condition chip, or null for "All conditions".
  String? _condition;

  /// What the doctor typed in the search bar (trimmed).
  String _query = '';

  /// Needed so the "clear" button can empty the text field itself.
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Asks the service for the patients and updates the screen state.
  /// [showSkeleton] is false for pull-to-refresh, because the spinner is enough.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) setState(() => _status = _LoadStatus.loading);
    try {
      final patients = await PatientsService.instance.fetchPatients();
      // The doctor may have left the screen while we waited.
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _status = _LoadStatus.ready;
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  /// Patients of the selected pill (Active or History), before search and condition.
  List<Patient> get _inSelectedStatus =>
      _patients.where((p) => p.isActive == _showActive).toList();

  /// The condition chips: every different condition in the selected pill.
  List<String> get _conditions {
    final names = _inSelectedStatus.map((p) => p.condition).toSet().toList();
    names.sort();
    return names;
  }

  /// The patients to show: selected pill + condition chip + search text.
  List<Patient> get _visiblePatients {
    final query = _query.toLowerCase();
    return _inSelectedStatus.where((p) {
      final matchesCondition = _condition == null || p.condition == _condition;
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.condition.toLowerCase().contains(query);
      return matchesCondition && matchesQuery;
    }).toList();
  }

  /// Switches between Active and History. The condition chips are different
  /// in each, so the chosen condition is reset.
  void _selectStatus(bool showActive) {
    setState(() {
      _showActive = showActive;
      _condition = null;
    });
  }

  /// Empties the search bar and the condition chip.
  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _condition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header: back arrow + title, then a thin divider (as in the prototype)
          RecordsHeader(title: 'Patients', onBack: widget.onBack, backTooltip: 'Back to Home'),

          // Body: centered, max width, pull-to-refresh
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
      // Loading: skeleton placeholders shaped like the pills, search bar and cards
      case _LoadStatus.loading:
        return [
          const SkeletonBox(height: 44, width: 200, radius: 999),
          gap,
          const SkeletonBox(height: 52, radius: AppRadius.md),
          gap,
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(height: 92, radius: AppRadius.md),
            gap,
          ],
        ];

      // Error: message + "Try again" button
      case _LoadStatus.error:
        return [ErrorState(message: _error, onRetry: _load)];

      case _LoadStatus.ready:
        // Empty: the doctor has no patients at all
        if (_patients.isEmpty) {
          return [
            const EmptyState(
              icon: Icons.groups_rounded,
              title: 'No patients yet',
              message: 'Patients you see will appear here after their first visit.',
            ),
          ];
        }

        final visible = _visiblePatients;
        return [
          // Active / History pills
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _pill(label: 'Active', selected: _showActive, onTap: () => _selectStatus(true)),
              _pill(label: 'History', selected: !_showActive, onTap: () => _selectStatus(false)),
            ],
          ),
          gap,

          // Search bar (name or condition)
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: AppTheme.inputDecoration(hint: 'Search by name or condition').copyWith(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          gap,

          // Condition filter chips
          Text(
            'Filter by condition',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _pill(
                label: 'All conditions',
                selected: _condition == null,
                onTap: () => setState(() => _condition = null),
              ),
              for (final name in _conditions)
                _pill(
                  label: name,
                  selected: _condition == name,
                  onTap: () => setState(() => _condition = name),
                ),
            ],
          ),
          gap,

          // Empty: patients exist, but none match the pill, search or condition
          if (visible.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching patients',
              message: 'Try another name or condition, or switch between Active and History.',
              actionLabel: 'Clear search and filter',
              onAction: _clearFilters,
            ),

          // List of patient cards (each fades in a little after the one above)
          for (var i = 0; i < visible.length; i++) ...[
            FadeSlideIn(
              // The key makes Flutter replay the animation when the pill changes.
              key: ValueKey('$_showActive-${visible[i].id}'),
              delay: Duration(milliseconds: 60 * i),
              child: PatientCard(
                patient: visible[i],
                onTap: () => widget.onOpenPatient(visible[i]),
              ),
            ),
            gap,
          ],
        ];
    }
  }

  /// One pill-shaped choice (used for Active / History and the condition chips).
  /// Selected = navy with white text and a check mark; not selected = outlined.
  Widget _pill({required String label, required bool selected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.brandNavy,
      backgroundColor: AppColors.surface,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      side: BorderSide(color: selected ? AppColors.brandNavy : AppColors.border),
    );
  }
}
