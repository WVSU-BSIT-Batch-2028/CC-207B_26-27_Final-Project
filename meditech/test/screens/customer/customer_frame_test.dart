import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/screens/customer/customer_frame.dart';
import 'package:meditech/widgets/theme/app_theme.dart';

void main() {
  Widget buildTestableWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CustomerFrame(),
      ),
    );
  }

  testWidgets('renders customer frame header and navigation tabs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verifies app bar branding
    expect(find.text('MediTech'), findsOneWidget);

    // Verifies header action buttons
    expect(find.byTooltip('AI Assistant'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Cart'), findsOneWidget);

    // Verifies bottom navigation destinations
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Verifies Home screen content
    expect(find.text('Search medicines or pharmacies...'), findsOneWidget);
    expect(find.text('Available medicines'), findsOneWidget);
    expect(find.text('Nearby pharmacies'), findsOneWidget);
  });

  testWidgets('switches tab when bottom navigation destination is tapped', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap on Search tab
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Should display search placeholder screen
    expect(find.text('Search Medicines'), findsOneWidget);

    // Tap on Reservations tab
    await tester.tap(find.text('Reservations'));
    await tester.pumpAndSettle();

    // Should display reservations placeholder screen
    expect(find.text('My Reservations'), findsOneWidget);
  });

  testWidgets('tapping search bar on home switches to search tab', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap the search bar
    await tester.tap(find.text('Search medicines or pharmacies...'));
    await tester.pumpAndSettle();

    // Should automatically navigate to search tab
    expect(find.text('Search Medicines'), findsOneWidget);
  });
}
