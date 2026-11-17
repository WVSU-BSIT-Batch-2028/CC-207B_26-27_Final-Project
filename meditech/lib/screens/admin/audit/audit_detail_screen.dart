import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/audit_record.dart';
import '../../../providers/audit_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// One platform event, opened from the audit list
class AuditDetailScreen extends ConsumerWidget {
  const AuditDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(auditDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Audit record')),
      body: AsyncView<AuditRecord?>(
        value: detail,
        isEmpty: (data) => data == null,
        emptyMessage: 'This audit record was not found.',
        onRetry: () => ref.invalidate(auditDetailProvider(id)),
        builder: (data) {
          final record = data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Row(label: 'ID', value: record.displayId),
              _Row(label: 'When', value: record.createdAt.toUtc().toIso8601String()),
              _Row(label: 'Who', value: record.actorLabel),
              if (record.actorRole != null) _Row(label: 'Role', value: record.actorRole!),
              _Row(label: 'Type', value: record.eventType),
              _Row(label: 'Action', value: record.action),
              if (record.recordRef != null) _Row(label: 'Record', value: record.recordRef!),
              _Row(label: 'Details', value: record.details.toString()),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(value),
        ],
      ),
    );
  }
}