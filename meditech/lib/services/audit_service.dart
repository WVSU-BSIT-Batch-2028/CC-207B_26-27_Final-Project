import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_record.dart';
import '../utils/app_failure.dart';

// Loads audit rows and asks the server for a CSV export
abstract class AuditService {
  Future<List<AuditRecord>> loadAll();
  Future<AuditRecord?> loadOne(String id);
  Future<String> exportCsv();
}

class SupabaseAuditService implements AuditService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<AuditRecord>> loadAll() async {
    final rows = await _client
        .from('audit_records')
        .select(
          'id, display_id, actor_label, actor_role, event_type, action, record_ref, details, created_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final row in rows) AuditRecord.fromJson(row)];
  }

  @override
  Future<AuditRecord?> loadOne(String id) async {
    final row = await _client
        .from('audit_records')
        .select(
          'id, display_id, actor_label, actor_role, event_type, action, record_ref, details, created_at',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return AuditRecord.fromJson(row);
  }

  // The CSV comes from the Edge Function so the export is recorded
    @override
    Future<String> exportCsv() async {
    try {
        final response = await _client.functions.invoke(
        'audit-export',
        body: {},
        );
        final data = response.data;
        if (data is Map && data['csv'] is String && (data['csv'] as String).isNotEmpty) {
        return data['csv'] as String;
        }
        throw const AppFailure('Could not export the audit records.');
    } on FunctionException catch (error) {
        final details = error.details;
        if (details is Map) {
        final message = details['error'];
        if (message is String && message.isNotEmpty) throw AppFailure(message);
        }
        if (error.status == 0) throw const AppFailure('Could not reach Supabase.');
        throw const AppFailure('Could not export the audit records.');
    }
    }
}