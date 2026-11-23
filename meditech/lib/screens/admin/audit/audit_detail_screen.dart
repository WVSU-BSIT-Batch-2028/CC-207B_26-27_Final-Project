import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/audit_providers.dart';
import 'audit_drawer.dart';

// Full-page fallback when opened via /audit/:id (drawer layout, close goes back)
class AuditDetailScreen extends ConsumerWidget {
  const AuditDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 420,
        child: AuditDrawer(
          recordId: id,
          onClose: () {
            ref.read(selectedAuditProvider.notifier).select(null);
            if (context.mounted) context.pop();
          },
        ),
      ),
    );
  }
}