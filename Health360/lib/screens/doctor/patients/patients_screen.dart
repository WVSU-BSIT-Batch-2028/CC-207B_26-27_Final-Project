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

/// The three states the screen can be in while it loads data.
enum _LoadStatus { loading, ready, error }

/// Doctor Patients page.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({
    super.key,
    required this.onBack,
    required this.onOpenPatient,
  });

  final VoidCallback onBack;
  final ValueChanged<Patient> onOpenPatient;

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<Patient> _patients = const [];
  String _error = '';

  /// true = Active pill, false = History pill.
  bool _showActive = true;

  /// Selected condition chip, or null for All conditions.
  String? _condition;

  /// Search text entered by the doctor.
  String _query = '';

  /// Controller for the search field.
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

  /// Loads the patients and updates the screen.
  Future<void> _load({bool showSkeleton = true}) async {
    if (showSkeleton) {
      setState(() => _status = _LoadStatus.loading);
    }

    try {
      final patients = await PatientsService.instance.fetchPatients();

      if (!mounted) return;

      setState(() {
        _patients = patients;
        _status = _LoadStatus.ready;
        _error = '';
      });
    } on PatientsException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _status = _LoadStatus.error;
      });
    }
  }

  /// Patients belonging to the selected Active or History category.
  List<Patient> get _inSelectedStatus {
    return _patients
        .where((patient) => patient.isActive == _showActive)
        .toList();
  }

  /// Available condition chips in the selected category.
  /// Patients without recorded conditions are excluded.
  List<String> get _conditions {
    final names = _inSelectedStatus
        .map((patient) => patient.condition)
        .whereType<String>()
        .where((condition) => condition.trim().isNotEmpty)
        .toSet()
        .toList();

    names.sort();
    return names;
  }

  /// Patients matching the selected category, condition and search text.
  List<Patient> get _visiblePatients {
    final query = _query.toLowerCase();

    return _inSelectedStatus.where((patient) {
      final condition = patient.condition;

      final matchesCondition = _condition == null || condition == _condition;

      final matchesQuery = query.isEmpty ||
          patient.name.toLowerCase().contains(query) ||
          condition.toLowerCase().contains(query);

      return matchesCondition && matchesQuery;
    }).toList();
  }

  /// Switches between Active and History.
  void _selectStatus(bool showActive) {
    setState(() {
      _showActive = showActive;
      _condition = null;
    });
  }

  /// Clears the search text and selected condition.
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
          RecordsHeader(
            title: 'Patients',
            onBack: widget.onBack,
            backTooltip: 'Back to Home',
          ),
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

  /// Builds the content for loading, error, empty and ready states.
  List<Widget> _buildChildren() {
    const gap = SizedBox(height: AppSpacing.md);

    switch (_status) {
      case _LoadStatus.loading:
        return [
          const SkeletonBox(
            height: 44,
            width: 200,
            radius: 999,
          ),
          gap,
          const SkeletonBox(
            height: 52,
            radius: AppRadius.md,
          ),
          gap,
          for (var i = 0; i < 3; i++) ...[
            const SkeletonBox(
              height: 92,
              radius: AppRadius.md,
            ),
            gap,
          ],
        ];

      case _LoadStatus.error:
        return [
          ErrorState(
            message: _error,
            onRetry: _load,
          ),
        ];

      case _LoadStatus.ready:
        if (_patients.isEmpty) {
          return [
            const EmptyState(
              icon: Icons.groups_rounded,
              title: 'No patients yet',
              message:
                  'Patients who book appointments with you will appear here.',
            ),
          ];
        }

        final visible = _visiblePatients;

        return [
          // Active and History pills.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _pill(
                label: 'Active',
                selected: _showActive,
                onTap: () => _selectStatus(true),
              ),
              _pill(
                label: 'History',
                selected: !_showActive,
                onTap: () => _selectStatus(false),
              ),
            ],
          ),
          gap,

          // Search by patient name or condition.
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _query = value.trim());
            },
            decoration: AppTheme.inputDecoration(
              hint: 'Search by name or condition',
            ).copyWith(
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

          // Condition filter chips.
          Text(
            'Filter by condition',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _pill(
                label: 'All conditions',
                selected: _condition == null,
                onTap: () {
                  setState(() => _condition = null);
                },
              ),
              for (final name in _conditions)
                _pill(
                  label: name,
                  selected: _condition == name,
                  onTap: () {
                    setState(() => _condition = name);
                  },
                ),
            ],
          ),
          gap,

          // No matching patients.
          if (visible.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching patients',
              message:
                  'Try another name or condition, or switch between Active and History.',
              actionLabel: 'Clear search and filter',
              onAction: _clearFilters,
            ),

          // Patient cards.
          for (var i = 0; i < visible.length; i++) ...[
            FadeSlideIn(
              key: ValueKey(
                '$_showActive-${visible[i].id}',
              ),
              delay: Duration(milliseconds: 60 * i),
              child: PatientCard(
                patient: visible[i],
                onTap: () {
                  widget.onOpenPatient(visible[i]);
                },
              ),
            ),
            gap,
          ],
        ];
    }
  }

  /// Reusable pill for Active, History and condition filters.
  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
      side: BorderSide(
        color: selected ? AppColors.brandNavy : AppColors.border,
      ),
    );
  }
}
