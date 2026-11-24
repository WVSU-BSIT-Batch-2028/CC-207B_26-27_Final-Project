import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/branch_reservation_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/pharmacy/reservations/reservation_details_drawer.dart';
import 'package:meditech/screens/pharmacy/reservations/reservations_screen.dart';
import 'package:meditech/services/branch_reservation_service.dart';

class _StaffSession extends SessionNotifier {
  @override
  SignedInAccount? build() {
    return const SignedInAccount(
      accountType: 'staff',
      state: 'active',
      role: 'pharmacist',
      branchId: 'demo-branch',
    );
  }
}

void main() {
  testWidgets('clicking view opens the reservation details drawer with items',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeService = FakeBranchReservationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(_StaffSession.new),
        ],
        child: const MaterialApp(
          home: ReservationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial drawer is not present
    expect(find.byType(ReservationDetailsDrawer), findsNothing);

    // Tap the View action button for the first row (Grace Villanueva)
    final viewBtn = find.byTooltip('View details').first;
    await tester.tap(viewBtn);
    await tester.pumpAndSettle();

    // Verify drawer appears with details
    expect(find.byType(ReservationDetailsDrawer), findsOneWidget);
    expect(find.text('Confirm reservation'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Uploaded prescription'), findsOneWidget);
    expect(find.text('View Full Size'), findsOneWidget);
    expect(find.text('Total reported amount'), findsOneWidget);
    expect(find.text('₱252.00'), findsWidgets);
  });

  testWidgets('drawer displays ready for pickup with verify code input',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeService = FakeBranchReservationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(_StaffSession.new),
        ],
        child: const MaterialApp(
          home: ReservationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Select Luke Dela Cruz (Ready for Pickup)
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReservationsScreen)),
    );
    container.read(selectedReservationIdProvider.notifier).select('res-5');
    await tester.pumpAndSettle();

    expect(find.byType(ReservationDetailsDrawer), findsOneWidget);
    expect(find.text('Verify pickup code'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Cancel reservation'), findsOneWidget);
  });
}
