import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/pharmacy_summary.dart';
import 'package:meditech/providers/admin_pharmacy_providers.dart';
import 'package:meditech/screens/admin/pharmacies/pharmacies_screen.dart';

void main() {
  // The table shows pharmacies with their status
  testWidgets('shows pharmacies and statuses', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        pharmacyListProvider.overrideWith((ref) async => [
              PharmacySummary(
                id: 'a',
                displayId: 'PHM-000003',
                pharmacyName: 'Demo Waiting Pharmacy',
                branchName: 'Molo Branch',
                address: 'Molo, Iloilo City',
                ownerName: 'Rosa Villareal',
                ltoNumber: 'DEMO-LTO-0003',
                ltoExpiry: DateTime(2028, 12, 31),
                status: 'pending_approval',
                submittedAt: DateTime(2026, 11, 14),
                possibleDuplicate: false,
              ),
            ]),
      ],
      child: const MaterialApp(home: PharmaciesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Demo Waiting Pharmacy'), findsOneWidget);
    expect(find.text('Rosa Villareal'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets); // the tab and the badge
  });
}