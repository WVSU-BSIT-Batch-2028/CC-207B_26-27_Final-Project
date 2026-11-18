import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/providers/medicine_providers.dart';
import 'package:meditech/providers/reservation_providers.dart';
import 'package:meditech/screens/customer/customer_frame.dart';
import 'package:meditech/screens/customer/reservations/my_reservations_screen.dart';
import 'package:meditech/screens/customer/search/search_screen.dart';
import 'package:meditech/services/medicine_service.dart';
import 'package:meditech/services/reservation_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockMedicineService extends Mock implements MedicineService {}

class MockReservationService extends Mock implements ReservationService {}

void main() {
  late MockMedicineService mockMedicineService;
  late MockReservationService mockReservationService;

  setUp(() {
    mockMedicineService = MockMedicineService();
    mockReservationService = MockReservationService();

    when(() => mockMedicineService.getDosageForms())
        .thenAnswer((_) async => ['Tablet', 'Capsule']);
    when(
      () => mockMedicineService.searchMedicines(
        query: any(named: 'query'),
        strength: any(named: 'strength'),
        dosageForm: any(named: 'dosageForm'),
        location: any(named: 'location'),
        sort: any(named: 'sort'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => const []);
    when(() => mockReservationService.getMyReservations())
        .thenAnswer((_) async => const []);
  });

  Widget buildTestableWidget() {
    return ProviderScope(
      overrides: [
        medicineServiceProvider.overrideWithValue(mockMedicineService),
        reservationServiceProvider.overrideWithValue(mockReservationService),
      ],
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
    final navBar = find.byType(NavigationBar);
    expect(find.descendant(of: navBar, matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Search')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('My Reservations')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Profile')), findsOneWidget);

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

    final navBar = find.byType(NavigationBar);

    // Tap on Search tab
    await tester.tap(find.descendant(of: navBar, matching: find.text('Search')));
    await tester.pumpAndSettle();

    // Should display SearchScreen
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Try paracetamol or Biogesic'), findsOneWidget);

    // Tap on My Reservations tab
    await tester.tap(find.descendant(of: navBar, matching: find.text('My Reservations')));
    await tester.pumpAndSettle();

    // Should display MyReservationsScreen with status tabs
    expect(find.byType(MyReservationsScreen), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('No active reservations'), findsOneWidget);
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

    // Should automatically navigate to SearchScreen
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Try paracetamol or Biogesic'), findsOneWidget);
  });
}