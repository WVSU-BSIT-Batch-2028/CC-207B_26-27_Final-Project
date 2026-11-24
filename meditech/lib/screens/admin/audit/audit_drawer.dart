import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/audit_record.dart';
import '../../../providers/audit_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'audit_format.dart';

// Right-side drawer for one audit record (matches pharmacy application drawer)
class AuditDrawer extends ConsumerWidget {
  const AuditDrawer({
    super.key,
    required this.recordId,
    required this.onClose,
  });

  final String recordId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(auditDetailProvider(recordId));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(left: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: AsyncView<AuditRecord?>(
        value: detail,
        onRetry: () => ref.invalidate(auditDetailProvider(recordId)),
        isEmpty: (data) => data == null,
        emptyMessage: 'This audit record was not found.',
        builder: (record) => _AuditDrawerBody(record: record!, onClose: onClose),
      ),
    );
  }
}

class _AuditDrawerBody extends StatelessWidget {
  const _AuditDrawerBody({required this.record, required this.onClose});

  final AuditRecord record;
  final VoidCallback onClose;

  String _formatDetails(Map<String, dynamic> details) {
    if (details.isEmpty) return '—';
    return details.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Widget _labeledRows(List<(String, String)> rows) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(rows[i].$2, style: const TextStyle(fontSize: 14, height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
        ],
      );

  Widget _section(String title, List<(String, String)> rows) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _labeledRows(rows),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('MMM d, yyyy · h:mm a');
    final (typeLabel, typeTone) = auditEventTypeBadge(record.eventType);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayId,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      when.format(record.createdAt.toLocal()),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StatusBadge(typeLabel, tone: typeTone),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              _section('EVENT', [
                ('Action', record.action),
                if (record.recordRef != null) ('Record', record.recordRef!),
              ]),
              _section('ACTOR', [
                ('Name', record.actorLabel),
                if (record.actorRole != null) ('Role', record.actorRole!),
              ]),
              _section('DETAILS', [
                ('Payload', _formatDetails(record.details)),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}