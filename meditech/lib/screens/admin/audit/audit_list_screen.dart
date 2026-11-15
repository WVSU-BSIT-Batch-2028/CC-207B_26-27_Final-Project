import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/audit_record.dart';
import '../../../providers/audit_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// The administrator's list of platform events
class AuditListScreen extends ConsumerWidget {
  const AuditListScreen({super.key});

  // Ask the server for a CSV, then copy it so it can be pasted into a spreadsheet
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final csv = await ref.read(auditServiceProvider).exportCsv();
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied. Paste it into a spreadsheet.')),
        );
      }
    } on AppFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(auditListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit records'),
        actions: [
          TextButton(
            onPressed: () => _export(context, ref),
            child: const Text('Export CSV'),
          ),
        ],
      ),
      body: AsyncView<List<AuditRecord>>(
        value: list,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No audit records yet.',
        onRetry: () => ref.invalidate(auditListProvider),
        builder: (items) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => context.push('/audit/${item.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.displayId, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${item.eventType} · ${item.action}'),
                    Text(item.actorLabel),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}