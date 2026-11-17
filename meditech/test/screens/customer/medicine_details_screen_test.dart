import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/medicine.dart';
import 'package:meditech/providers/medicine_providers.dart';
import 'package:meditech/screens/customer/medicine/medicine_details_screen.dart';
import 'package:meditech/services/medicine_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockMedicineService extends Mock implements MedicineService {}

void main() {
  late MockMedicineService mockMedicineService;

  const sampleMedicine = MedicineSearchResult(
    medicineId: 'med-1',
    displayId: 'MED-001',
    brandName: 'Biogesic',
    genericName: 'Paracetamol',
    strength: '500 mg',
    dosageForm: 'Tablet',
    unitSold: 'tablet',
    isRx: false,
    lowestPrice: 4.50,
    pharmacyCount: 2,
  );

  const rxMedicine = MedicineSearchResult(
    medicineId: 'med-rx',
    displayId: 'MED-002',
    brandName: 'Amoxil',
    genericName: 'Amoxicillin',
    strength: '500 mg',
    dosageForm: 'Capsule',
    unitSold: 'capsule',
    isRx: true,
    lowestPrice: 12.00,
    pharmacyCount: 1,
  );

  final sampleOffers = <MedicineOffer>[
    MedicineOffer(
      inventoryId: 'inv-1',
      branchId: 'branch-1',
      branchDisplayId: 'BR-001',
      pharmacyName: 'Mercury Drug',
      branchName: 'Molo Plaza',
      address: 'Molo Plaza, Iloilo City',
      pricePerUnit: 4.50,
      availability: MedicineAvailability.available,
      stockConfirmedAt: DateTime(2026, 11, 17, 10, 0),
    ),
    MedicineOffer(
      inventoryId: 'inv-2',
      branchId: 'branch-2',
      branchDisplayId: 'BR-002',
      pharmacyName: 'Watsons Pharmacy',
      branchName: 'SM City',
      address: 'Mandurriao, Iloilo City',
      pricePerUnit: 5.00,
      availability: MedicineAvailability.unavailable,
      stockConfirmedAt: DateTime(2026, 11, 17, 9, 30),
    ),
  ];

  setUp(() {
    mockMedicineService = MockMedicineService();
    when(
      () => mockMedicineService.getMedicineOffers(
        medicineId: any(named: 'medicineId'),
        sort: any(named: 'sort'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => sampleOffers);
  });

  Widget buildSubject({
    MedicineSearchResult medicine = sampleMedicine,
    void Function(MedicineSearchResult, MedicineOffer)? onAddToCart,
  }) {
    return ProviderScope(
      overrides: [
        medicineServiceProvider.overrideWithValue(mockMedicineService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MedicineDetailsScreen(
          medicine: medicine,
          onAddToCart: onAddToCart,
        ),
      ),
    );
  }

  testWidgets('renders medicine header, pharmacy offers, and availability states',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Paracetamol'), findsOneWidget);
    expect(find.text('Mercury Drug'), findsOneWidget);
    expect(find.text('Molo Plaza'), findsOneWidget);
    expect(find.text('Watsons Pharmacy'), findsOneWidget);

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('Add to Cart'), findsOneWidget);
  });

  testWidgets('displays Rx notice when medicine requires prescription',
      (tester) async {
    await tester.pumpWidget(buildSubject(medicine: rxMedicine));
    await tester.pumpAndSettle();

    expect(find.text('Rx'), findsOneWidget);
    expect(find.text('Prescription required at pickup.'), findsOneWidget);
  });

  testWidgets('calls onAddToCart when Add to Cart is tapped on available offer',
      (tester) async {
    MedicineOffer? addedOffer;

    await tester.pumpWidget(
      buildSubject(
        onAddToCart: (_, offer) => addedOffer = offer,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to Cart'));
    await tester.pump();

    expect(addedOffer?.branchId, 'branch-1');
  });
}