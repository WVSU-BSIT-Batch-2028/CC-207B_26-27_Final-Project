import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/medicine_request.dart';
import 'package:meditech/providers/medicine_request_providers.dart';
import 'package:meditech/screens/admin/requests/medicine_requests_screen.dart';

void main() {
  // An open request shows its details and both actions
  testWidgets('shows an open request with actions', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        requestListProvider.overrideWith((ref) async => [
              MedicineRequest(
                id: 'r1',
                displayId: 'REQ-000001',
                genericName: 'Cefalexin',
                brandName: 'Keflex',
                strength: '500 mg',
                status: 'open',
                pharmacyName: 'Demo Pharmacy',
                branchName: 'La Paz Branch',
                requestedBy: 'Ana Lim',
                createdAt: DateTime(2026, 11, 18),
              ),
            ]),
      ],
      child: const MaterialApp(home: MedicineRequestsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cefalexin'), findsOneWidget);
    expect(find.text('Keflex · 500 mg'), findsOneWidget);
    expect(find.text('Mark as added'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });
}
