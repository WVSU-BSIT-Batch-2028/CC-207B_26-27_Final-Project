import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/theme/app_tokens.dart';
import 'package:littlesteps/widgets/responsive_layout.dart';

void main() {
  group('AppWindowSize', () {
    test('classifies widths into Material 3 window size classes', () {
      expect(AppWindowSize.fromWidth(320), AppWindowSize.compact);
      expect(AppWindowSize.fromWidth(599), AppWindowSize.compact);
      expect(AppWindowSize.fromWidth(600), AppWindowSize.medium);
      expect(AppWindowSize.fromWidth(839), AppWindowSize.medium);
      expect(AppWindowSize.fromWidth(840), AppWindowSize.expanded);
      expect(AppWindowSize.fromWidth(1280), AppWindowSize.expanded);
    });
  });

  group('ResponsiveContentBox', () {
    testWidgets('constrains child width to maxWidth on wide viewports', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: ResponsiveContentBox(
                maxWidth: 600,
                child: SizedBox(key: ValueKey('inner'), width: double.infinity),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const ValueKey('inner')));
      expect(size.width, 600);
    });
  });

  group('AdaptiveTwoPane', () {
    testWidgets('stacks panes vertically below twoColumnBreakpoint', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: AppSizes.twoColumnBreakpoint - 100,
              child: AdaptiveTwoPane(
                primary: SizedBox(key: ValueKey('primary'), height: 100),
                secondary: SizedBox(key: ValueKey('secondary'), height: 100),
              ),
            ),
          ),
        ),
      );

      final primaryRect = tester.getRect(find.byKey(const ValueKey('primary')));
      final secondaryRect = tester.getRect(
        find.byKey(const ValueKey('secondary')),
      );
      expect(secondaryRect.top, greaterThanOrEqualTo(primaryRect.bottom));
    });

    testWidgets('places panes side by side at or above twoColumnBreakpoint', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: AppSizes.twoColumnBreakpoint + 100,
              child: AdaptiveTwoPane(
                primary: SizedBox(key: ValueKey('primary'), height: 100),
                secondary: SizedBox(key: ValueKey('secondary'), height: 100),
              ),
            ),
          ),
        ),
      );

      final primaryRect = tester.getRect(find.byKey(const ValueKey('primary')));
      final secondaryRect = tester.getRect(
        find.byKey(const ValueKey('secondary')),
      );
      expect(secondaryRect.left, greaterThanOrEqualTo(primaryRect.right));
      expect(secondaryRect.width, AppSizes.sidePanelWidth);
    });
  });
}
