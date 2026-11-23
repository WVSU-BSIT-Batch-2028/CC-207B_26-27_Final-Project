import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/medicine.dart';
import 'package:meditech/models/pharmacy.dart';
import 'package:meditech/providers/pharmacy_providers.dart';
import 'package:meditech/screens/customer/pharmacy/pharmacy_details_screen.dart';
import 'package:meditech/services/pharmacy_service.dart';
import 'package:meditech/widgets/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class MockPharmacyService extends Mock implements PharmacyService {}

void main() {
  late MockPharmacyService mockPharmacyService;

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

  final sampleHours = <PharmacyHours>[
    const PharmacyHours(weekday: 0, isClosed: true),
    for (var weekday = 1; weekday <= 6; weekday++)
      PharmacyHours(
        weekday: weekday,
        opensAt: '08:00:00',
        closesAt: '20:00:00',
        isClosed: false,
      ),
  ];

  final sampleInventory = [
    PharmacyInventoryItem(
      inventoryId: 'inv-1',
      medicineId: 'med-1',
      medicineDisplayId: 'MED-001',
      brandName: 'Biogesic',
      genericName: 'Paracetamol',
      strength: '500 mg',
      dosageForm: 'Tablet',
      unitSold: 'tablet',
      isRx: false,
      pricePerUnit: 5.50,
      availability: MedicineAvailability.available,
      stockConfirmedAt: DateTime(2026, 11, 17, 10, 0),
    ),
  ];

  setUp(() {
    mockPharmacyService = MockPharmacyService();
    when(
      () => mockPharmacyService.getPharmacyDetails(
        branchId: any(named: 'branchId'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => sampleBranch);

    when(
      () => mockPharmacyService.getPharmacyHours(
        branchId: any(named: 'branchId'),
      ),
    ).thenAnswer((_) async => sampleHours);

    when(
      () => mockPharmacyService.getPharmacyInventory(
        branchId: any(named: 'branchId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => sampleInventory);
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        pharmacyServiceProvider.overrideWithValue(mockPharmacyService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PharmacyDetailsScreen(branchId: 'branch-1'),
      ),
    );
  }

  testWidgets('renders pharmacy branch info, opening hours, and inventory',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Mercury Drug'), findsNWidgets(2));
    expect(find.text('Molo Plaza'), findsOneWidget);
    expect(find.text('Molo Plaza, Iloilo City'), findsOneWidget);
    expect(find.text('09171110001'), findsOneWidget);
    final today = pharmacyHoursForToday(sampleHours)!;
    expect(find.text('Opening Hours'), findsOneWidget);
    expect(find.text(today.dayLabel), findsOneWidget);
    expect(find.text(today.scheduleLabel), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Biogesic'),
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('₱5.50 / tablet'), findsOneWidget);
  });

  testWidgets('renders Get directions button in header card', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Get directions'),
      findsOneWidget,
    );
  });
}