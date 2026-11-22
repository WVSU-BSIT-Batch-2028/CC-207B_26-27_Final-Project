import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/cart.dart';
import 'package:meditech/models/pharmacy.dart';
import 'package:meditech/models/reservation.dart';
import 'package:meditech/providers/cart_providers.dart';
import 'package:meditech/providers/pharmacy_providers.dart';
import 'package:meditech/providers/reservation_providers.dart';
import 'package:meditech/screens/customer/pharmacy/directions_screen.dart';
import 'package:meditech/screens/customer/reservations/reservation_details_screen.dart';
import 'package:meditech/services/cart_service.dart';
import 'package:meditech/services/pharmacy_service.dart';
import 'package:meditech/services/reservation_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockReservationService extends Mock implements ReservationService {}

class MockPharmacyService extends Mock implements PharmacyService {}

class MockCartService extends Mock implements CartService {}

void main() {
  late MockReservationService mockReservationService;
  late MockPharmacyService mockPharmacyService;
  late MockCartService mockCartService;

  final sampleCompletedReservation = CustomerReservation(
    id: 'res-1',
    referenceNo: 'RES-000001',
    branchId: 'branch-1',
    pharmacyName: 'Mercury Drug',
    branchName: 'Molo Plaza',
    branchAddress: 'Molo Plaza, Iloilo City',
    status: ReservationStatus.completed,
    hasRx: false,
    totalAmount: 110.0,
    submittedAt: DateTime(2026, 11, 20, 10, 0),
    expiresAt: DateTime(2026, 11, 27, 10, 0),
    updatedAt: DateTime(2026, 11, 20, 11, 0),
    items: const [
      ReservationItem(
        lineNo: 1,
        medicineId: 'med-1',
        quantity: 2,
        brandName: 'Biogesic',
        genericName: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Tablet',
        unitSold: 'tablet',
        isRx: false,
        unitPrice: 5.5,
      ),
    ],
  );

  final sampleConfirmedReservation = CustomerReservation(
    id: 'res-2',
    referenceNo: 'RES-000002',
    branchId: 'branch-1',
    pharmacyName: 'Mercury Drug',
    branchName: 'Molo Plaza',
    branchAddress: 'Molo Plaza, Iloilo City',
    status: ReservationStatus.confirmed,
    hasRx: false,
    totalAmount: 110.0,
    submittedAt: DateTime(2026, 11, 21, 10, 0),
    expiresAt: DateTime(2026, 11, 28, 10, 0),
    updatedAt: DateTime(2026, 11, 21, 10, 30),
    items: const [
      ReservationItem(
        lineNo: 1,
        medicineId: 'med-1',
        quantity: 2,
        brandName: 'Biogesic',
        genericName: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Tablet',
        unitSold: 'tablet',
        isRx: false,
        unitPrice: 5.5,
      ),
    ],
  );

  const sampleBranch = PharmacyDetail(
    branchId: 'branch-1',
    displayId: 'BR-001',
    pharmacyName: 'Mercury Drug',
    branchName: 'Molo Plaza',
    address: 'Molo Plaza, Iloilo City',
    contactNumber: '09171110001',
    latitude: 10.695,
    longitude: 122.545,
  );

  setUp(() {
    mockReservationService = MockReservationService();
    mockPharmacyService = MockPharmacyService();
    mockCartService = MockCartService();

    when(
      () => mockPharmacyService.getPharmacyDetails(
        branchId: any(named: 'branchId'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => sampleBranch);

    when(() => mockReservationService.getMyReservations())
        .thenAnswer((_) async => [sampleCompletedReservation]);

    when(() => mockCartService.getMyCart())
        .thenAnswer((_) async => const CustomerCart());

    when(
      () => mockCartService.addToCart(
        branchId: any(named: 'branchId'),
        medicineId: any(named: 'medicineId'),
        quantity: any(named: 'quantity'),
        replaceBranch: any(named: 'replaceBranch'),
      ),
    ).thenAnswer((_) async => AddToCartOutcome.added);
  });

  Widget buildSubject(CustomerReservation reservation) {
    when(() => mockReservationService.getReservationById(reservation.id))
        .thenAnswer((_) async => reservation);

    return ProviderScope(
      overrides: [
        reservationServiceProvider.overrideWithValue(mockReservationService),
        pharmacyServiceProvider.overrideWithValue(mockPharmacyService),
        cartServiceProvider.overrideWithValue(mockCartService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: ReservationDetailsScreen(reservationId: reservation.id),
      ),
    );
  }

  testWidgets(
    'renders Get directions button in pharmacy card and opens directions',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(sampleConfirmedReservation));
      await tester.pumpAndSettle();

      final getDirectionsButton = find.widgetWithText(
        OutlinedButton,
        'Get directions',
      );
      expect(getDirectionsButton, findsOneWidget);

      await tester.tap(getDirectionsButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DirectionsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'renders Reorder button for completed reservation and triggers reorder',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(sampleCompletedReservation));
      await tester.pumpAndSettle();

      final reorderButton = find.widgetWithText(FilledButton, 'Reorder items');
      expect(reorderButton, findsOneWidget);

      await tester.tap(reorderButton);
      await tester.pumpAndSettle();

      verify(
        () => mockCartService.addToCart(
          branchId: 'branch-1',
          medicineId: 'med-1',
          quantity: 2,
          replaceBranch: false,
        ),
      ).called(1);
    },
  );

  testWidgets(
    'does not render Reorder button for confirmed active reservation',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject(sampleConfirmedReservation));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Reorder items'), findsNothing);
    },
  );
}
