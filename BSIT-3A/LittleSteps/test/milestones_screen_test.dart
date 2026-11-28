import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/milestone.dart';
import 'package:littlesteps/screens/milestones/milestones_screen.dart';

import 'fixtures/sample_milestone_prompts.dart';

void main() {
  Widget createTestWidget({
    MilestonesViewState state = MilestonesViewState.ready,
    Map<String, MilestoneObservation> observations = const {},
  }) {
    return MaterialApp(
      home: MilestonesScreen(
        initialState: state,
        prompts: sampleMilestonePrompts,
        initialObservations: observations,
      ),
    );
  }

  group('MilestonesScreen UI & State Tests', () {
    testWidgets('displays advisory banner and prompt domain headers', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('LittleSteps is not a diagnostic tool'), findsOneWidget);
      expect(
        find.text('Every child develops at their own pace.'),
        findsOneWidget,
      );
      expect(find.text('Thinking'), findsWidgets);
      expect(find.text('Talking'), findsWidgets);
    });

    testWidgets('filters prompts when domain chip is tapped', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Talking'));
      await tester.pumpAndSettle();

      expect(
        find.text('Points to familiar objects when named'),
        findsOneWidget,
      );
      expect(find.text('Finds a hidden toy'), findsNothing);
    });

    testWidgets('opens observation sheet and records observation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap first Add button
      final addButton = find.widgetWithText(FilledButton, 'Add').first;
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Bottom sheet is visible
      expect(find.text('Note what you saw'), findsOneWidget);
      expect(find.text('I saw it'), findsOneWidget);

      // Enter a note
      await tester.enterText(
        find.byType(TextField),
        'Watched during playtime.',
      );
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Card updates to "Update"
      expect(find.widgetWithText(OutlinedButton, 'Update'), findsOneWidget);
      expect(find.text('Watched during playtime.'), findsOneWidget);
    });

    testWidgets('displays error state with retry button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: MilestonesViewState.error),
      );
      await tester.pumpAndSettle();

      expect(find.text("We couldn't load this right now"), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('displays offline banner in offline state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: MilestonesViewState.offline),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("You're offline"), findsOneWidget);
    });

    testWidgets('strict non-diagnostic banned words audit', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      const bannedWords = [
        'delayed',
        'behind',
        'on track',
        'normal',
        'abnormal',
        'score',
        'pass',
        'fail',
      ];

      for (final prompt in sampleMilestonePrompts) {
        for (final word in bannedWords) {
          expect(
            prompt.title.toLowerCase().contains(word),
            isFalse,
            reason: 'Prompt "${prompt.title}" contains banned word "$word"',
          );
        }
      }
    });
  });
}
