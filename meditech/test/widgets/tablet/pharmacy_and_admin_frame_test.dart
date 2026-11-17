import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet.dart';

void main() {
  testWidgets('PharmacyFrame hides Employees for pharmacist and shows it for owner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Pharmacist should not see Employees
    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyFrame(
          branchName: 'Supreme Pharmacy · La Paz Branch',
          branchMeta: 'PHM-000001 · La Paz, Iloilo City',
          userName: 'Jose Reyes',
          userRole: 'Pharmacist',
          pendingReservationsCount: 3,
          stockAlertsCount: 7,
          selectedNavigationId: 'dashboard',
          onNavigationSelected: (_) {},
          body: const Text('Pharmacy Body'),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Stock Alerts'), findsOneWidget);
    expect(find.text('Employees'), findsNothing);
    expect(find.text('Branch settings'), findsOneWidget);

    // Owner should see Employees
    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyFrame(
          branchName: 'Supreme Pharmacy · La Paz Branch',
          userName: 'Maria Santos',
          userRole: 'Owner',
          selectedNavigationId: 'employees',
          onNavigationSelected: (_) {},
          body: const Text('Employees Body'),
        ),
      ),
    );

    expect(find.text('Employees'), findsOneWidget);
  });

  testWidgets('AdminFrame renders admin navigation and Log out label',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AdminFrame(
          headerSubtitle: 'Iloilo City pilot',
          adminName: 'Paolo Reyes',
          pendingPharmaciesCount: 3,
          medicineRequestsCount: 2,
          selectedNavigationId: 'overview',
          onNavigationSelected: (_) {},
          body: const Text('Admin Overview'),
        ),
      ),
    );

    expect(find.text('MediTech Administration'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Pharmacies'), findsOneWidget);
    expect(find.text('Medicine Catalogue'), findsOneWidget);
    expect(find.text('Audit Records'), findsOneWidget);
    expect(find.text('Branch settings'), findsNothing);
    expect(find.text('Log out'), findsOneWidget);
  });
}