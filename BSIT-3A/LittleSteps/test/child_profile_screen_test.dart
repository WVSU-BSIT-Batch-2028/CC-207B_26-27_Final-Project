import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/children/child_profile_screen.dart';
import 'package:littlesteps/theme/app_theme.dart';

void main() {
  testWidgets('tapping anywhere on an inactive child card switches child', (
    tester,
  ) async {
    Child? selectedChild;
    final now = DateTime(2026, 11, 24);
    final children = [
      Child(
        id: 'c1',
        nickname: 'Maya',
        ageBand: '12-23m',
        createdAt: now,
        updatedAt: now,
      ),
      Child(
        id: 'c2',
        nickname: 'Leo',
        ageBand: '6-11m',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ChildProfileScreen(
          children: children,
          onChildSelected: (child) => selectedChild = child,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Leo'), findsOneWidget);
    expect(find.text('Tap to switch'), findsWidgets);

    // Tapping the nickname on the card body selects that child.
    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();

    expect(selectedChild?.id, 'c2');
    expect(selectedChild?.nickname, 'Leo');
    expect(find.text('Switched to Leo'), findsOneWidget);
  });
}
