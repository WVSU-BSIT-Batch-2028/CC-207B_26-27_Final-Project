import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/activity_log_entry.dart';
import '../../../providers/activity_log_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// The owner's list of pharmacy events, same layout style as audit records
class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(activityLogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: AsyncView<List<ActivityLogEntry>>(
        value: list,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No activity yet, or only an owner can see this log.',
        onRetry: () => ref.invalidate(activityLogProvider),
        builder: (items) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.action, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.actorLabel),
                  if (item.actorRole != null) Text(item.actorRole!),
                  Text(item.createdAt.toUtc().toIso8601String()),
                ],
              );
            },
          );
        },
      ),
    );
  }
}