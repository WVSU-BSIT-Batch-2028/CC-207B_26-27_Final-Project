import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/activity_log_entry.dart';
import 'package:meditech/providers/activity_log_providers.dart';
import 'package:meditech/screens/pharmacy/activity_log/activity_log_screen.dart';
import 'package:meditech/services/activity_log_service.dart';

void main() {
  // The owner sees the newest pharmacy events
  testWidgets('shows activity rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityLogServiceProvider.overrideWithValue(_FakeActivityLogService())],
        child: const MaterialApp(home: ActivityLogScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmed a reservation'), findsOneWidget);
    expect(find.text('Demo Owner'), findsOneWidget);
  });
}

class _FakeActivityLogService implements ActivityLogService {
  @override
  Future<List<ActivityLogEntry>> loadMine() async {
    return [
      ActivityLogEntry(
        id: 1,
        actorLabel: 'Demo Owner',
        actorRole: 'owner',
        action: 'Confirmed a reservation',
        createdAt: DateTime.utc(2026, 11, 17),
      ),
    ];
  }
}