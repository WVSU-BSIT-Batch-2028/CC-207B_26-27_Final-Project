import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/cart.dart';
import 'package:meditech/models/medicine.dart';
import 'package:meditech/models/reservation.dart';
import 'package:meditech/providers/cart_providers.dart';
import 'package:meditech/providers/reservation_providers.dart';
import 'package:meditech/screens/customer/cart/cart_screen.dart';
import 'package:meditech/services/cart_service.dart';
import 'package:meditech/services/reservation_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockCartService extends Mock implements CartService {}

class MockReservationService extends Mock implements ReservationService {}

void main() {
  late MockCartService mockCartService;
  late MockReservationService mockReservationService;

  const otcItem = CartItem(
    branchId: 'branch-1',
    pharmacyName: 'Mercury Drug',
    branchName: 'Molo Plaza',
    branchAddress: 'Molo Plaza, Iloilo City',
    medicineId: 'med-1',
    brandName: 'Biogesic',
    genericName: 'Paracetamol',
    strength: '500 mg',
    dosageForm: 'Tablet',
    unitSold: 'tablet',
    isRx: false,
    quantity: 2,
    pricePerUnit: 5.00,
    availability: MedicineAvailability.available,
  );

  const rxItem = CartItem(
    branchId: 'branch-1',
    pharmacyName: 'Mercury Drug',
    branchName: 'Molo Plaza',
    branchAddress: 'Molo Plaza, Iloilo City',
    medicineId: 'med-2',
    brandName: 'Amoxil',
    genericName: 'Amoxicillin',
    strength: '500 mg',
    dosageForm: 'Capsule',
    unitSold: 'capsule',
    isRx: true,
    quantity: 1,
    pricePerUnit: 12.00,
    availability: MedicineAvailability.available,
  );

  setUp(() {
    mockCartService = MockCartService();
    mockReservationService = MockReservationService();
    when(() => mockReservationService.getMyReservations())
        .thenAnswer((_) async => const []);
  });

  Widget buildSubject(CustomerCart initialCart) {
    when(() => mockCartService.getMyCart()).thenAnswer((_) async => initialCart);

    return ProviderScope(
      overrides: [
        cartServiceProvider.overrideWithValue(mockCartService),
        reservationServiceProvider.overrideWithValue(mockReservationService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CartScreen(),
      ),
    );
  }

  testWidgets('P-13 renders empty state when cart has no items',
      (tester) async {
    await tester.pumpWidget(buildSubject(const CustomerCart()));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty.'), findsOneWidget);
    expect(find.text('Browse Medicines'), findsOneWidget);
  });

  testWidgets('P-15 renders single-branch cart items and reported total',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(const CustomerCart(items: [otcItem])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mercury Drug'), findsOneWidget);
    expect(find.text('Molo Plaza'), findsOneWidget);
    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Total reported amount (2 units)'), findsOneWidget);
    expect(find.text('₱10.00'), findsNWidgets(2));
  });

  testWidgets('P-17 blocks reservation checkout when Rx item lacks prescription',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(const CustomerCart(items: [rxItem])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prescription needed (0/3)'), findsOneWidget);
    expect(
      find.text('Upload at least one prescription file to continue.'),
      findsOneWidget,
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Place reservation'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'P-19 places reservation after acknowledgment and shows confirmation',
      (tester) async {
    when(() => mockReservationService.generateIdempotencyKey())
        .thenReturn('11111111-1111-4111-8111-111111111111');
    when(
      () => mockReservationService.submitReservation(
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
        acknowledged: true,
      ),
    ).thenAnswer(
      (_) async => const SubmittedReservationResult(
        reservationId: 'res-1',
        referenceNo: 'RM-111826-0001',
      ),
    );

    await tester.pumpWidget(
      buildSubject(const CustomerCart(items: [otcItem])),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Place reservation'),
      200,
    );

    // Button stays disabled until acknowledgment checkbox is checked
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Place reservation'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Place reservation'));
    await tester.pumpAndSettle();

    expect(find.text('Reservation submitted'), findsOneWidget);
    expect(find.text('RM-111826-0001'), findsOneWidget);
  });
}