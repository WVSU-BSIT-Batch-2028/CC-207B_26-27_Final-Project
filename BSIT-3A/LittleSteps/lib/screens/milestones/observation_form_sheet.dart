import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/milestone.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/state_views.dart';

/// Modal bottom sheet for recording an observation for a prompt.
///
/// Allows caregivers to mark whether a milestone was observed and optionally save
/// private notes and the observation date.
class ObservationFormSheet extends StatefulWidget {
  /// Creates an [ObservationFormSheet].
  const ObservationFormSheet({
    super.key,
    required this.prompt,
    required this.childName,
    required this.childAgeMonths,
    this.initialObservation,
    this.isOffline = false,
    this.onRetryOffline,
    required this.onSave,
  });

  /// Milestone prompt being recorded or edited.
  final MilestonePrompt prompt;

  /// Display nickname of the active child.
  final String childName;

  /// Approximate age of the active child in months.
  final int childAgeMonths;

  /// Existing saved observation when editing, if any.
  final MilestoneObservation? initialObservation;

  /// Whether the app is currently offline.
  final bool isOffline;

  /// Optional callback to retry connectivity from the offline banner.
  final VoidCallback? onRetryOffline;

  /// Callback invoked with the saved [MilestoneObservation].
  final ValueChanged<MilestoneObservation> onSave;

  @override
  State<ObservationFormSheet> createState() => _ObservationFormSheetState();
}

class _ObservationFormSheetState extends State<ObservationFormSheet> {
  late bool _isObserved;
  late DateTime _selectedDate;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _isObserved = widget.initialObservation?.isObserved ?? true;
    _selectedDate = widget.initialObservation != null
        ? DateTime.tryParse(widget.initialObservation!.observedDate) ??
              DateTime.now()
        : DateTime.now();
    _notesController = TextEditingController(
      text: widget.initialObservation?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final obs = MilestoneObservation(
      id:
          widget.initialObservation?.id ??
          'obs-${DateTime.now().millisecondsSinceEpoch}',
      childId: widget.initialObservation?.childId ?? 'child-maya',
      milestoneId: widget.prompt.id,
      status: _isObserved
          ? MilestoneObservation.statusObserved
          : MilestoneObservation.statusNotYetObserved,
      observedDate: dateStr,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.initialObservation?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(obs);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionTitleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );
    final dateDisplay = DateFormat('MMM d').format(_selectedDate);
    final isToday =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space16,
        right: AppSpacing.space16,
        top: AppSpacing.space16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: AppColors.forest,
                  ),
                  Text(
                    'Milestones',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            if (widget.isOffline)
              OfflineStatusCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.space16),
                message: "Your note wasn't saved. Keep this screen open and tap Retry when you're back online.",
                onRetry: widget.onRetryOffline,
              ),
            Text(
              'Note what you saw',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '${widget.prompt.domain.label} · ${widget.prompt.ageBand}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12,
                vertical: AppSpacing.space8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: [
                  Text(
                    'For ${widget.childName} · ${widget.childAgeMonths} months',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                widget.prompt.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('What did you see?', style: sectionTitleStyle),
            const SizedBox(height: AppSpacing.space8),
            Row(
              children: [
                Expanded(
                  child: _ObservationStatusToggle(
                    label: 'I saw it',
                    selected: _isObserved,
                    onTap: () => setState(() => _isObserved = true),
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: _ObservationStatusToggle(
                    label: 'Not seen yet',
                    selected: !_isObserved,
                    onTap: () => setState(() => _isObserved = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('When did you see it?', style: sectionTitleStyle),
            const SizedBox(height: AppSpacing.space8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Container(
                height: AppSizes.touchTarget,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    Text(
                      isToday ? 'Today, $dateDisplay' : dateDisplay,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text('Note (optional)', style: sectionTitleStyle),
            const SizedBox(height: AppSpacing.space8),
            TextField(
              controller: _notesController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'What happened? Describe what you saw in your own words.',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.space4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_notesController.text.length}/500',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            SizedBox(
              height: AppSizes.touchTarget,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            SizedBox(
              height: AppSizes.touchTarget,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderSubtle),
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationStatusToggle extends StatelessWidget {
  const _ObservationStatusToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        height: AppSizes.touchTargetSecondary,
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AppColors.surfaceCard : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
