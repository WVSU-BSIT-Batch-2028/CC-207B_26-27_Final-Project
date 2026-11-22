import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/medicine_providers.dart';
import 'package:meditech/providers/reservation_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/customer/customer_frame.dart';
import 'package:meditech/screens/customer/reservations/my_reservations_screen.dart';
import 'package:meditech/screens/customer/search/search_screen.dart';
import 'package:meditech/services/medicine_service.dart';
import 'package:meditech/services/reservation_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockMedicineService extends Mock implements MedicineService {}

class MockReservationService extends Mock implements ReservationService {}

// A signed-in customer, so the frame lets them into My Reservations
class _SignedInCustomer extends SessionNotifier {
  @override
  SignedInAccount? build() =>
      const SignedInAccount(accountType: 'customer', state: 'active');
}

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

  // Guests by default; My Reservations and Profile need a signed-in customer
  Widget buildTestableWidget({bool signedIn = false}) {
    return ProviderScope(
      overrides: [
        medicineServiceProvider.overrideWithValue(mockMedicineService),
        reservationServiceProvider.overrideWithValue(mockReservationService),
        if (signedIn) sessionProvider.overrideWith(_SignedInCustomer.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const CustomerFrame()),
    );
  }

  testWidgets('renders customer frame header and navigation tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verifies header action buttons
    expect(find.byTooltip('AI Assistant'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Cart'), findsOneWidget);

    // Verifies bottom navigation destinations
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Reservations'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);

    // Verifies Home screen content
    expect(find.text('Find medicine near you'), findsOneWidget);
    expect(find.text('Search medicine...'), findsOneWidget);
    expect(find.text('Browse All Stores'), findsOneWidget);
  });

  testWidgets('switches tab when bottom navigation destination is tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(signedIn: true));
    await tester.pumpAndSettle();

    // Tap on Search tab
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // Should display SearchScreen
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search medicine...'), findsOneWidget);

    // Tap on My Reservations tab
    await tester.tap(find.byTooltip('Reservations'));
    await tester.pumpAndSettle();

    // Should display MyReservationsScreen with status tabs
    expect(find.byType(MyReservationsScreen), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('No active reservations'), findsOneWidget);
  });

  // Guests are asked to sign in and stay on their current tab
  testWidgets('guest tapping My Reservations is asked to sign in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reservations'));
    await tester.pumpAndSettle();

    expect(find.text('Create an account'), findsOneWidget); // the sign-in sheet
    expect(find.byType(MyReservationsScreen), findsNothing); // still on Home
    expect(find.text('Find medicine near you'), findsOneWidget);
  });

  testWidgets('tapping search bar on home switches to search tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap the search bar
    await tester.tap(find.text('Search medicine...'));
    await tester.pumpAndSettle();

    // Should automatically navigate to SearchScreen
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search medicine...'), findsOneWidget);
  });
}
