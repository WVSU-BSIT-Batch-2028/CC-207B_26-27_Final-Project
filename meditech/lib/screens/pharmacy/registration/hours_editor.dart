import 'package:flutter/material.dart';

import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';

// Weekly operating schedule: a compact list where one day opens at a time
class HoursEditor extends StatefulWidget {
  const HoursEditor({super.key, required this.draft, this.serverError});

  final RegistrationDraft draft;
  final String? serverError;

  @override
  State<HoursEditor> createState() => _HoursEditorState();
}

class _HoursEditorState extends State<HoursEditor> {
  static const _names = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  static const _order = [1, 2, 3, 4, 5, 6, 0]; // Monday first
  static const _weekdays = {1, 2, 3, 4, 5};

  int? _expanded; // the day that's open for editing, if any

  List<DayHoursDraft> get _days => widget.draft.days;

  // Minutes since midnight, for comparing times
  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // An open day must close after it opens
  bool _validTimes(DayHoursDraft day) =>
      _minutes(day.closesAt) > _minutes(day.opensAt);

  // Check the whole schedule when Continue is pressed
  String? _check() {
    if (!_days.any((d) => d.isOpen)) return 'Open at least one day.';
    for (final i in _order) {
      if (_days[i].isOpen && !_validTimes(_days[i])) {
        return '${_names[i]}: closing time must be after opening time.';
      }
    }
    return null;
  }

  // Copy one day's hours to other open days; closed days stay closed
  void _apply(
    int from,
    FormFieldState<bool> field, {
    bool weekdaysOnly = false,
  }) {
    final source = _days[from];
    var count = 0;
    setState(() {
      for (var i = 0; i < 7; i++) {
        if (i == from || !_days[i].isOpen) continue;
        if (weekdaysOnly && !_weekdays.contains(i)) continue;
        _days[i].opensAt = source.opensAt;
        _days[i].closesAt = source.closesAt;
        count++;
      }
    });
    field.didChange(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No other open days to copy to.'
              : 'Copied to $count open ${count == 1 ? 'day' : 'days'}.',
        ),
      ),
    );
  }

  // Turn "same hours for all open days" on or off
  void _setSameHours(bool on, FormFieldState<bool> field) {
    setState(() {
      widget.draft.sameHours = on;
      _expanded = null;
      if (on) {
        // Start from the first open day's hours, and give them to every day
        final source = _order
            .map((i) => _days[i])
            .firstWhere((d) => d.isOpen, orElse: () => _days[1]);
        for (final day in _days) {
          day.opensAt = source.opensAt;
          day.closesAt = source.closesAt;
        }
      }
    });
    field.didChange(true);
  }

  // Ask for a time
  Future<TimeOfDay?> _pickTime(TimeOfDay current) =>
      showTimePicker(context: context, initialTime: current);

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      validator: (_) => _check(),
      builder: (field) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          final error = field.errorText ?? widget.serverError;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly operating schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Set the days and hours your pharmacy is open.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),

              // Same hours for every open day
              Material(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CheckboxListTile(
                  value: widget.draft.sameHours,
                  onChanged: (v) => _setSameHours(v ?? false, field),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  title: const Text(
                    'Use the same hours for all open days',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'One set of hours for every day you\'re open.',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // One set of times, when same hours is on
              if (widget.draft.sameHours) ...[
                _sharedTimes(field),
                const SizedBox(height: AppSpacing.md),
              ],

              // The seven days
              for (final i in _order) _dayRow(i, field, narrow),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Opening and closing time used by every open day
  Widget _sharedTimes(FormFieldState<bool> field) {
    final first = _days[1];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeField(
              label: 'Opens at',
              time: first.opensAt,
              onTap: () async {
                final t = await _pickTime(first.opensAt);
                if (t == null) return;
                setState(() {
                  for (final day in _days) {
                    day.opensAt = t;
                  }
                });
                field.didChange(true);
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _TimeField(
              label: 'Closes at',
              time: first.closesAt,
              onTap: () async {
                final t = await _pickTime(first.closesAt);
                if (t == null) return;
                setState(() {
                  for (final day in _days) {
                    day.closesAt = t;
                  }
                });
                field.didChange(true);
              },
            ),
          ),
        ],
      ),
    );
  }

  // One day: checkbox, name, badge, hours summary, and the expandable time settings
  Widget _dayRow(int i, FormFieldState<bool> field, bool narrow) {
    final day = _days[i];
    final expanded = _expanded == i;
    final canExpand = day.isOpen && !widget.draft.sameHours;
    final badTimes = day.isOpen && !_validTimes(day);
    final summary = day.isOpen
        ? '${day.opensAt.format(context)} – ${day.closesAt.format(context)}'
        : 'Closed';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: badTimes
              ? AppColors.danger
              : expanded
              ? AppColors.primary
              : AppColors.border,
          width: expanded || badTimes ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // The always-visible row; tap it to open or close the day
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: canExpand
                ? () => setState(() => _expanded = expanded ? null : i)
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    Checkbox(
                      value: day.isOpen,
                      onChanged: (v) {
                        setState(() {
                          day.isOpen = v ?? false;
                          if (!day.isOpen && _expanded == i) _expanded = null;
                        });
                        field.didChange(true);
                      },
                    ),
                    SizedBox(
                      width: narrow ? 84 : 100,
                      child: Text(
                        _names[i],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!narrow) ...[
                      day.isOpen
                          ? const StatusBadge('Open', tone: BadgeTone.success)
                          : const StatusBadge('Closed'),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Row(
                        children: [
                          if (day.isOpen) ...[
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: badTimes
                                  ? AppColors.danger
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              summary,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: badTimes
                                    ? AppColors.danger
                                    : day.isOpen
                                    ? AppColors.text
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canExpand)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // The time settings, sliding open and closed
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _dayPanel(i, field)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // The opened day: two time pickers and the copy actions
  Widget _dayPanel(int i, FormFieldState<bool> field) {
    final day = _days[i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Opens at',
                  time: day.opensAt,
                  onTap: () async {
                    final t = await _pickTime(day.opensAt);
                    if (t == null) return;
                    setState(() => day.opensAt = t);
                    field.didChange(true);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _TimeField(
                  label: 'Closes at',
                  time: day.closesAt,
                  onTap: () async {
                    final t = await _pickTime(day.closesAt);
                    if (t == null) return;
                    setState(() => day.closesAt = t);
                    field.didChange(true);
                  },
                ),
              ),
            ],
          ),
          if (!_validTimes(day))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Closing time must be after opening time.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          // Copy these hours to other open days
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Apply to all open days'),
                onPressed: () => _apply(i, field),
              ),
              TextButton(
                onPressed: () => _apply(i, field, weekdaysOnly: true),
                child: const Text('Weekdays only'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Copies these hours to other open days. Closed days stay closed.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A time box that opens the time picker when tapped
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(time.format(context))),
                const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
