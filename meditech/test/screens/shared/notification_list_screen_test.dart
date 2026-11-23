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
        overrides: [notificationListProvider.overrideWith(_FixedList.new)],
        child: const MaterialApp(home: NotificationListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reservation ready'), findsOneWidget);
    expect(find.byTooltip('Mark as read'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as read'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark as read'), findsNothing);
    expect(find.text('Clear notifications'), findsOneWidget);
  });

  testWidgets('mark all as read clears unread indicators', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationListProvider.overrideWith(_FixedListWithTwo.new)],
        child: const MaterialApp(home: NotificationListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark as read'), findsNWidgets(2));
    await tester.tap(find.text('Mark all as read').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark as read'), findsNothing);
  });

  // The bell shows how many are unread
  testWidgets('bell shows the unread count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationListProvider.overrideWith(_FixedList.new),
          sessionProvider.overrideWith(_SignedInSession.new),
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
  SignedInAccount? build() {
    return const SignedInAccount(accountType: 'customer', state: 'active');
  }
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

class _FixedListWithTwo extends NotificationListNotifier {
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
      AppNotification(
        id: 'two',
        title: 'New reservation',
        body: 'A customer submitted a request.',
        readAt: null,
        createdAt: DateTime.utc(2026, 11, 14),
      ),
    ];
  }

  @override
  Future<void> markAllRead() async {
    final readAt = DateTime.utc(2026, 11, 15, 2);
    final current = state.value ?? [];
    state = AsyncData([
      for (final item in current) item.copyWith(readAt: readAt),
    ]);
  }
}