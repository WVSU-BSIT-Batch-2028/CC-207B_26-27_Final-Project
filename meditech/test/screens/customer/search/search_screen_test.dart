import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/medicine.dart';
import 'package:meditech/providers/medicine_providers.dart';
import 'package:meditech/screens/customer/search/search_screen.dart';
import 'package:meditech/services/medicine_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMedicineService extends Mock implements MedicineService {}

void main() {
  late MockMedicineService mockService;

  setUp(() {
    mockService = MockMedicineService();
    when(() => mockService.getDosageForms())
        .thenAnswer((_) async => ['Tablet', 'Capsule']);
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        medicineServiceProvider.overrideWithValue(mockService),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SearchScreen()),
      ),
    );
  }

  testWidgets('renders medicine results with price and Rx badge', (tester) async {
    when(
      () => mockService.searchMedicines(
        query: any(named: 'query'),
        strength: any(named: 'strength'),
        dosageForm: any(named: 'dosageForm'),
        location: any(named: 'location'),
        sort: any(named: 'sort'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer(
      (_) async => const [
        MedicineSearchResult(
          medicineId: 'med-1',
          displayId: 'MED-000001',
          brandName: 'Biogesic',
          genericName: 'Paracetamol',
          strength: '500 mg',
          dosageForm: 'Tablet',
          unitSold: 'tablet',
          isRx: false,
          lowestPrice: 4.25,
          pharmacyCount: 2,
        ),
        MedicineSearchResult(
          medicineId: 'med-2',
          displayId: 'MED-000002',
          brandName: 'Amoxil',
          genericName: 'Amoxicillin',
          strength: '500 mg',
          dosageForm: 'Capsule',
          unitSold: 'capsule',
          isRx: true,
          lowestPrice: 11.50,
          pharmacyCount: 3,
        ),
      ],
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.textContaining('Paracetamol'), findsOneWidget);
    expect(find.textContaining('From ₱4.25 / tablet'), findsOneWidget);
    expect(find.text('Amoxil'), findsOneWidget);
    expect(find.text('Rx required'), findsOneWidget);
  });

  testWidgets('shows empty state message when no medicines match', (tester) async {
    when(
      () => mockService.searchMedicines(
        query: any(named: 'query'),
        strength: any(named: 'strength'),
        dosageForm: any(named: 'dosageForm'),
        location: any(named: 'location'),
        sort: any(named: 'sort'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('No matching medicines found.'), findsOneWidget);
  });
}