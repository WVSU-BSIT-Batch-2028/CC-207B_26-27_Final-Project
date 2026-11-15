import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_record.dart';
import '../services/audit_service.dart';

final auditServiceProvider = Provider<AuditService>((ref) {
  return SupabaseAuditService();
});

final auditListProvider = FutureProvider<List<AuditRecord>>((ref) {
  return ref.watch(auditServiceProvider).loadAll();
});

final auditDetailProvider =
    FutureProvider.family<AuditRecord?, String>((ref, id) {
  return ref.watch(auditServiceProvider).loadOne(id);
});