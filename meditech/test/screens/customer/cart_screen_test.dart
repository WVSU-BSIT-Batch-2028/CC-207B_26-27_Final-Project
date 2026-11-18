import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/cart.dart';
import 'package:meditech/models/medicine.dart';
import 'package:meditech/providers/cart_providers.dart';
import 'package:meditech/screens/customer/cart/cart_screen.dart';
import 'package:meditech/services/cart_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockCartService extends Mock implements CartService {}

void main() {
  late MockCartService mockCartService;

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
  });

  Widget buildSubject(CustomerCart initialCart) {
    when(() => mockCartService.getMyCart()).thenAnswer((_) async => initialCart);

    return ProviderScope(
      overrides: [
        cartServiceProvider.overrideWithValue(mockCartService),
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

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Browse Medicines'), findsOneWidget);
  });

  testWidgets('P-14 renders single-branch cart items and subtotal',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(const CustomerCart(items: [otcItem])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mercury Drug'), findsOneWidget);
    expect(find.text('Molo Plaza'), findsOneWidget);
    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Subtotal (2 items)'), findsOneWidget);
    expect(find.text('₱10.00'), findsNWidgets(2));
  });

  testWidgets('P-14 blocks reservation checkout when Rx item lacks prescription',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(const CustomerCart(items: [rxItem])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prescription required'), findsOneWidget);
    expect(
      find.text('Upload your prescription above to continue.'),
      findsOneWidget,
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Proceed to Reservation'),
    );
    expect(button.onPressed, isNull);
  });
}