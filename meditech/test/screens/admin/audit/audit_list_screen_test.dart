import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/audit_record.dart';
import 'package:meditech/providers/audit_providers.dart';
import 'package:meditech/screens/admin/audit/audit_list_screen.dart';
import 'package:meditech/services/audit_service.dart';

void main() {
  // The list shows the newest audit rows
  testWidgets('shows audit rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [auditServiceProvider.overrideWithValue(_FakeAuditService())],
        child: const MaterialApp(home: AuditListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AUD-000001'), findsOneWidget);
    expect(find.text('Sign-in'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Demo Admin'), findsOneWidget);
  });
}

class _FakeAuditService implements AuditService {
  @override
  Future<String> exportCsv() async => 'display_id\nAUD-000001';

  @override
  Future<List<AuditRecord>> loadAll() async {
    return [
      AuditRecord(
        id: 'one',
        displayId: 'AUD-000001',
        actorLabel: 'Demo Admin',
        eventType: 'sign_in',
        action: 'Signed in',
        details: const {},
        createdAt: DateTime.utc(2026, 11, 15),
      ),
    ];
  }

  @override
  Future<AuditRecord?> loadOne(String id) async => null;
}