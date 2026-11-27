//updated to be functional - Joshua
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project_look_out/widgets/loader.dart';

import '../../../widgets/lookout_app_bar.dart';

import 'package:flutter/material.dart';

class LogsScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const LogsScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final logsStream = FirebaseFirestore.instance
        .collection('logs')
        .snapshots();

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'Activity Logs',
        onMenuPressed: onMenuPressed,
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Monitoring',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recent account, feedback, and FAQ changes recorded by '
                    'administrators.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: logsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Unable to load activity logs: ${snapshot.error}',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Loader.circular();
                      }

                      final entries = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final timeA = a.data()['createdAt'];
                          final timeB = b.data()['createdAt'];
                          final valueA = timeA is Timestamp
                              ? timeA.millisecondsSinceEpoch
                              : 0;
                          final valueB = timeB is Timestamp
                              ? timeB.millisecondsSinceEpoch
                              : 0;
                          return valueB.compareTo(valueA);
                        });
                      final logs = entries
                          .map(_ActivityLog.fromDocument)
                          .toList();
                      final now = DateTime.now();
                      final todayCount = entries.where((entry) {
                        final value = entry.data()['createdAt'];
                        if (value is! Timestamp) return false;
                        final date = value.toDate().toLocal();
                        return date.year == now.year &&
                            date.month == now.month &&
                            date.day == now.day;
                      }).length;
                      final adminActions = entries
                          .where((entry) => entry.data()['actorUid'] != null)
                          .length;
                      final alerts = entries
                          .where((entry) => entry.data()['type'] == 'Alert')
                          .length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _LogMetric(
                                label: 'Events today',
                                value: '$todayCount',
                                icon: Icons.receipt_long_outlined,
                              ),
                              _LogMetric(
                                label: 'Admin actions',
                                value: '$adminActions',
                                icon: Icons.admin_panel_settings_outlined,
                              ),
                              _LogMetric(
                                label: 'Alerts',
                                value: '$alerts',
                                icon: Icons.warning_amber_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Recent activity',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                'Latest first',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (logs.isEmpty)
                            const Text('No activity has been recorded.')
                          else
                            for (
                              var index = 0;
                              index < logs.length;
                              index++
                            ) ...[
                              if (index == 0 ||
                                  logs[index].date != logs[index - 1].date)
                                _LogDateHeading(date: logs[index].date),
                              _ActivityLogTile(
                                log: logs[index],
                                isLast: index == logs.length - 1,
                              ),
                            ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogMetric extends StatelessWidget {
  const _LogMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 50) / 2,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogDateHeading extends StatelessWidget {
  const _LogDateHeading({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Text(
        date,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({required this.log, required this.isLast});

  final _ActivityLog log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = switch (log.type) {
      'Account' => colors.primary,
      'Feedback' => colors.tertiary,
      'Alert' => colors.error,
      _ => Colors.green,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  child: Icon(log.icon, size: 19),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          log.time,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(log.description, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.actor,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        _LogTypeTag(label: log.type, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTypeTag extends StatelessWidget {
  const _LogTypeTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActivityLog {
  const _ActivityLog({
    required this.date,
    required this.time,
    required this.title,
    required this.description,
    required this.actor,
    required this.type,
    required this.icon,
  });

  final String date;
  final String time;
  final String title;
  final String description;
  final String actor;
  final String type;
  final IconData icon;

  factory _ActivityLog.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final type = data['type'] as String? ?? 'Activity';
    final timestamp = data['createdAt'];
    final date = timestamp is Timestamp
        ? _formatLogDate(timestamp.toDate().toLocal())
        : 'Date unavailable';
    final time = timestamp is Timestamp
        ? _formatLogTime(timestamp.toDate().toLocal())
        : '';
    return _ActivityLog(
      date: date,
      time: time,
      title: data['title'] as String? ?? type,
      description: data['description'] as String? ?? '',
      actor: data['actor'] as String? ?? 'System',
      type: type,
      icon: switch (type) {
        'Account' => Icons.manage_accounts_outlined,
        'Feedback' => Icons.feedback_outlined,
        'Alert' => Icons.warning_amber_outlined,
        'Content' => Icons.edit_note_outlined,
        _ => Icons.receipt_long_outlined,
      },
    );
  }
}

String _formatLogDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _formatLogTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
