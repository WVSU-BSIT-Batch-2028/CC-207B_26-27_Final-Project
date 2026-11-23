import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/app_notification.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/notification_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/shared/notification_bell.dart';
import 'package:meditech/screens/shared/notification_list_screen.dart';

void main() {
  // Mark as read hides the button for that notification
  testWidgets('mark as read updates the row', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_SignedInSession.new),
          notificationListProvider.overrideWith(_FixedList.new),
        ],
        child: const MaterialApp(home: NotificationListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reservation ready'), findsOneWidget);
    expect(find.byTooltip('Unread'), findsOneWidget);
    await tester.tap(find.text('Reservation ready'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Unread'), findsNothing);
    expect(find.text('Clear Notifications'), findsOneWidget);
  });

  // The bell shows how many are unread
  testWidgets('bell shows the unread count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_SignedInSession.new),
          notificationListProvider.overrideWith(_FixedList.new),
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationBell())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });
}

class _SignedInSession extends SessionNotifier {
  @override
  SignedInAccount? build() => const SignedInAccount(
        accountType: 'customer',
        state: 'active',
      );
}

class _FixedList extends NotificationListNotifier {
  @override
  Future<List<AppNotification>> build() async {
    return [
      AppNotification(
        id: 'one',
        title: 'Reservation ready',
        body: 'Pick it up today.',
        readAt: null,
        createdAt: DateTime.utc(2026, 11, 15),
      ),
    ];
  }

  @override
  Future<void> markRead(String id) async {
    final current = state.value ?? [];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) item.copyWith(readAt: DateTime.utc(2026, 11, 15, 1)) else item,
    ]);
  }
}