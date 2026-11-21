import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/admin_overview.dart';
import 'package:meditech/models/catalogue_medicine.dart';
import 'package:meditech/models/medicine_request.dart';
import 'package:meditech/models/pharmacy_summary.dart';
import 'package:meditech/providers/admin_overview_providers.dart';
import 'package:meditech/providers/admin_pharmacy_providers.dart';
import 'package:meditech/providers/catalogue_providers.dart';
import 'package:meditech/providers/medicine_request_providers.dart';
import 'package:meditech/screens/admin/catalogue/catalogue_screen.dart';
import 'package:meditech/screens/admin/overview/admin_overview_screen.dart';
import 'package:meditech/screens/admin/pharmacies/pharmacies_screen.dart';
import 'package:meditech/screens/admin/requests/medicine_requests_screen.dart';

const _overview = AdminOverview(
  pendingApplications: 7,
  activePharmacies: 2,
  inactivePharmacies: 0,
  medicinesPendingReview: 1,
  activeMedicines: 15,
  openRequests: 4,
  ltoExpiringSoon: 1,
  todo: [
    TodoItem(
      kind: 'application',
      id: 'b1',
      title: 'Demo Waiting Pharmacy · Molo Branch',
      detail: 'New pharmacy application',
    ),
  ],
);

// One pharmacy of each kind the cards care about
PharmacySummary _pharmacy(String name, String status, DateTime ltoExpiry) => PharmacySummary(
  id: name,
  displayId: 'PHM-$name',
  pharmacyName: name,
  branchName: 'Main Branch',
  address: 'Iloilo City',
  ownerName: 'Owner',
  ltoNumber: 'LTO-$name',
  ltoExpiry: ltoExpiry,
  status: status,
  submittedAt: DateTime(2026, 11, 1),
  possibleDuplicate: false,
);

final _far = DateTime.now().add(const Duration(days: 400));
final _soon = DateTime.now().add(const Duration(days: 20));
final _pharmacies = [
  _pharmacy('Pending Pharmacy', 'pending_approval', _far),
  _pharmacy('Active Pharmacy', 'active', _far),
  _pharmacy('Expiring Pharmacy', 'active', _soon),
  _pharmacy('Rejected Pharmacy', 'rejected', _far),
];

Future<void> _pumpOverview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminOverviewProvider.overrideWith((ref) async => _overview),
        pharmacyListProvider.overrideWith((ref) async => _pharmacies),
        catalogueListProvider.overrideWith((ref) async => const <CatalogueMedicine>[]),
        requestListProvider.overrideWith((ref) async => const <MedicineRequest>[]),
      ],
      child: const MaterialApp(home: AdminOverviewScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

void main() {
  // Cards show counts and the to-do list shows waiting items
  testWidgets('shows counts and to-do items', (tester) async {
    await _pumpOverview(tester);

    expect(find.text('Pending applications'), findsOneWidget);
    expect(find.text('7'), findsWidgets); // the card and the "at a glance" bar
    expect(find.text('7 waiting'), findsOneWidget); // quick actions
    expect(find.text('Demo Waiting Pharmacy · Molo Branch'), findsOneWidget);
  });

  // Each pharmacy card opens the pharmacies list showing only what it counts
  for (final (card, shown) in [
    ('Pending applications', ['Pending Pharmacy']),
    ('Active pharmacies', ['Active Pharmacy', 'Expiring Pharmacy']),
    ('LTOs expiring in 60 days', ['Expiring Pharmacy']),
  ]) {
    testWidgets('"$card" opens pharmacies filtered', (tester) async {
      await _pumpOverview(tester);

      await tester.tap(find.text(card));
      await tester.pumpAndSettle();

      expect(find.byType(PharmaciesScreen), findsOneWidget);
      for (final p in _pharmacies) {
        final name = p.pharmacyName;
        expect(find.text(name), shown.contains(name) ? findsOneWidget : findsNothing, reason: name);
      }
    });
  }

  // The medicines card opens the catalogue on "Pending review", even if another tab was left on
  testWidgets('"Medicines pending review" opens the catalogue filtered', (tester) async {
    await _pumpOverview(tester);
    _container(tester).read(catalogueFilterProvider.notifier).setStatus('active');

    await tester.tap(find.text('Medicines pending review'));
    await tester.pumpAndSettle();

    expect(find.byType(CatalogueScreen), findsOneWidget);
    expect(_container(tester).read(catalogueFilterProvider).status, 'draft');
  });

  // The requests card opens requests on "Open", even if another tab was left on
  testWidgets('"Open requests" opens requests filtered', (tester) async {
    await _pumpOverview(tester);
    _container(tester).read(requestStatusProvider.notifier).set('added');

    await tester.tap(find.text('Open requests'));
    await tester.pumpAndSettle();

    expect(find.byType(MedicineRequestsScreen), findsOneWidget);
    expect(_container(tester).read(requestStatusProvider), 'open');
  });
}
