import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/recommendation.dart';
import '../../services/ai_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/domain_labels.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/responsive_layout.dart';
import 'widgets/activity_adapt_section.dart';
import 'widgets/activity_materials_wrap.dart';
import 'widgets/explore_activity_card.dart';

/// Route arguments passed when navigating to [ActivityDetailScreen].
class ActivityDetailArgs {
  /// Creates an [ActivityDetailArgs] wrapping [activity] and [startInAdaptMode].
  const ActivityDetailArgs({
    required this.activity,
    this.startInAdaptMode = false,
  });

  /// Activity to display and optionally adapt.
  final Activity activity;

  /// Whether adaptation controls should start expanded on entry.
  final bool startInAdaptMode;
}

/// Screen displaying full activity steps, materials, provenance, and AI adaptation controls.
class ActivityDetailScreen extends StatefulWidget {
  /// Creates an [ActivityDetailScreen] for [activity].
  const ActivityDetailScreen({
    super.key,
    required this.activity,
    this.startInAdaptMode = false,
    this.aiService,
    this.onAddToPlan,
  });

  /// Activity to display and optionally adapt.
  final Activity activity;

  /// Whether the activity adaptation controls start expanded.
  final bool startInAdaptMode;

  /// Optional AI service override for requesting activity adaptations.
  final AiService? aiService;

  /// Optional callback invoked when the caregiver schedules the original or adapted activity.
  final Future<void> Function(Activity activity)? onAddToPlan;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final TextEditingController _missingMaterialController =
      TextEditingController();
  final GlobalKey _adaptSectionKey = GlobalKey();

  late bool _showAdaptForm;
  String _selectedAdjustment = ActivityAdjustments.shorter;
  bool _isAdapting = false;
  bool _isScheduling = false;
  String? _adaptError;
  AdaptActivityResponse? _adaptedResponse;

  @override
  void initState() {
    super.initState();
    _showAdaptForm = widget.startInAdaptMode;
    if (widget.startInAdaptMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _adaptSectionKey.currentContext;
        if (mounted && targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: AppMotion.durationFast,
            curve: AppMotion.easingStandard,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _missingMaterialController.dispose();
    super.dispose();
  }

  AiService? get _effectiveAiService {
    if (widget.aiService != null) return widget.aiService;
    final session = AuthScope.maybeOf(context);
    if (session == null || !session.isAuthenticated) return null;
    return AiService(apiClient: AuthScope.apiClientOf(context));
  }

  Future<void> _requestAdaptation() async {
    final service = _effectiveAiService;
    if (service == null) {
      setState(() {
        _adaptError = 'Please sign in to adjust this activity.';
      });
      return;
    }

    final missing = _missingMaterialController.text.trim();
    if (_selectedAdjustment == ActivityAdjustments.missingMaterial &&
        missing.isEmpty) {
      setState(() {
        _adaptError = 'Enter the material you are missing first.';
      });
      return;
    }

    setState(() {
      _isAdapting = true;
      _adaptError = null;
    });

    try {
      final result = await service.adaptActivity(
        activityId: widget.activity.id,
        adjustment: _selectedAdjustment,
        missingMaterial:
            _selectedAdjustment == ActivityAdjustments.missingMaterial
            ? missing
            : null,
        ageBand: widget.activity.ageBand,
      );
      if (!mounted) return;
      setState(() {
        _adaptedResponse = result;
        _isAdapting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdapting = false;
        _adaptError =
            'Could not adjust this activity right now. Please try again.';
      });
    }
  }

  Future<void> _scheduleActivity(Activity target) async {
    if (widget.onAddToPlan == null || _isScheduling) return;
    setState(() => _isScheduling = true);
    try {
      await widget.onAddToPlan!(target);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isScheduling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = widget.activity;
    final domainLabel = friendlyDomainLabel(activity.domain);
    final settingLabel = formatSettingLabel(activity.setting);
    final isReviewed = activity.status == Activity.statusReviewedApproved;

    return Scaffold(
      appBar: AppBar(title: Text(activity.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: ResponsiveContentBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.space8,
                  runSpacing: AppSpacing.space8,
                  children: [
                    Chip(
                      label: Text(domainLabel),
                      backgroundColor: AppColors.softGreen,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    Chip(
                      label: Text(activity.durationEstimate),
                      avatar: const Icon(Icons.schedule_outlined, size: 16),
                    ),
                    Chip(label: Text(settingLabel)),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),
                Text('Materials needed', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.space8),
                MaterialPillsWrap(materials: activity.materials),
                const SizedBox(height: AppSpacing.space16),
                Text('Steps to play', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.space8),
                NumberedStepsList(steps: activity.instructions),
                const SizedBox(height: AppSpacing.space12),
                KeyedSubtree(
                  key: _adaptSectionKey,
                  child: ActivityAdaptSection(
                    isExpanded: _showAdaptForm,
                    selectedAdjustment: _selectedAdjustment,
                    missingMaterialController: _missingMaterialController,
                    isAdapting: _isAdapting,
                    isScheduling: _isScheduling,
                    errorMessage: _adaptError,
                    adaptedResponse: _adaptedResponse,
                    onExpand: () => setState(() => _showAdaptForm = true),
                    onCollapse: () => setState(() {
                      _showAdaptForm = false;
                      _adaptError = null;
                    }),
                    onAdjustmentChanged: (value) => setState(() {
                      _selectedAdjustment = value;
                      _adaptError = null;
                    }),
                    onMissingMaterialChanged: (_) {
                      if (_adaptError != null) {
                        setState(() => _adaptError = null);
                      }
                    },
                    onSubmit: _requestAdaptation,
                    onTryAnother: () => setState(() {
                      _adaptedResponse = null;
                      _showAdaptForm = true;
                    }),
                    onAddAdapted:
                        widget.onAddToPlan != null && _adaptedResponse != null
                        ? () => _scheduleActivity(
                            _adaptedResponse!.adapted.toActivity(activity),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.space16),
                ReviewProvenanceBadge(
                  reviewed: isReviewed,
                  source: activity.provenanceSource,
                  limitations: activity.limitations,
                ),
                if (widget.onAddToPlan != null) ...[
                  const SizedBox(height: AppSpacing.space24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isScheduling
                          ? null
                          : () => _scheduleActivity(activity),
                      icon: const Icon(Icons.add),
                      label: const Text("Add to today's plan"),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.space24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
