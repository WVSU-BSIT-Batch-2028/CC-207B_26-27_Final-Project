import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/main.dart';
import 'package:littlesteps/models/book.dart';
import 'package:littlesteps/models/plan.dart';
import 'package:littlesteps/screens/explore/play_companion_dialog.dart';
import 'package:littlesteps/screens/today/today_screen.dart';

void main() {
  test('AppScrollBehavior enables touch, mouse, trackpad, and stylus drag', () {
    const behavior = AppScrollBehavior();
    expect(
      behavior.dragDevices,
      containsAll(<PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      }),
    );
  });

  test('CustomPlanActivity round-trips JSON and converts to Activity', () {
    const snapshot = CustomPlanActivity(
      title: 'Shoe Box Sorting',
      domain: 'cognitive',
      durationMinutes: 15,
      setting: 'indoor',
      materials: ['shoes'],
      instructions: ['Line up pairs of shoes.', 'Match each pair together.'],
      safetyNotice: 'Keep laces tucked away.',
      sourceLabel: 'Material adaptation',
    );

    final decoded = CustomPlanActivity.fromJson(snapshot.toJson());
    expect(decoded.title, 'Shoe Box Sorting');
    expect(decoded.domain, 'cognitive');
    expect(decoded.safetyNotice, 'Keep laces tucked away.');

    final activity = decoded.toActivity('custom-shoe-box-sorting');
    expect(activity.id, 'custom-shoe-box-sorting');
    expect(activity.provenanceSource, isEmpty);
    expect(activity.limitations, 'Keep laces tucked away.');
  });

  testWidgets('TodayScreen renders customActivity snapshot and detail sheet', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 25, 9, 0);
    final customPlan = PlanItem(
      id: 'plan-custom-1',
      childId: 'child-1',
      activityId: 'custom-shoe-box-sorting',
      scheduledDate: '2026-11-25',
      status: 'planned',
      durationMinutes: 15,
      customActivity: const CustomPlanActivity(
        title: 'Shoe Box Sorting',
        domain: 'cognitive',
        durationMinutes: 15,
        setting: 'indoor',
        materials: ['shoes'],
        instructions: ['Line up pairs of shoes.', 'Match each pair together.'],
        safetyNotice: 'Keep laces tucked away.',
        sourceLabel: 'Material adaptation',
      ),
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayScreen(
            initialState: TodayViewState.ready,
            initialPlans: [customPlan],
            initialDate: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shoe Box Sorting'), findsOneWidget);

    await tester.tap(find.text('Shoe Box Sorting'));
    await tester.pumpAndSettle();

    expect(find.text('Material adaptation'), findsOneWidget);
    expect(find.text('Line up pairs of shoes.'), findsOneWidget);
    expect(find.text('Keep laces tucked away.'), findsOneWidget);
    expect(find.textContaining('Source:'), findsNothing);
  });

  testWidgets(
    'PlayCompanionDialog allows two-line book title and shield icon',
    (tester) async {
      const book = BookItem(
        id: 'OL12345W',
        title: 'The Very Long Title of a Bedtime Picture Book for Toddlers',
        authors: ['Author Name'],
        subjects: ['Picture books'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayCompanionDialog(
              book: book,
              ideaTitle: 'Soft Story Walk',
              domain: 'language',
              instructions: 'Point to pictures and name animals together.',
              safetyNotice: 'Always stay close during play.',
            ),
          ),
        ),
      );

      final companionText = tester.widget<Text>(
        find.textContaining('Companion to '),
      );
      expect(companionText.maxLines, 2);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    },
  );
}
