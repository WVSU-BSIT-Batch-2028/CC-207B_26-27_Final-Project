import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet.dart';

void main() {
  testWidgets('TabletFrame renders header, filtered sidebar items, and body', (tester) async {
    const items = [
      TabletNavigationItem(id: 'dash', label: 'Dashboard', icon: Icons.dashboard),
      TabletNavigationItem(id: 'inv', label: 'Inventory', icon: Icons.inventory),
      TabletNavigationItem(
        id: 'emp',
        label: 'Employees',
        icon: Icons.people,
        allowedRoles: ['owner'],
      ),
    ];

    String selected = 'dash';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return TabletFrame(
              branchTitle: 'Supreme Pharmacy · La Paz',
              branchSubtitle: 'PHM-000001 · La Paz, Iloilo City',
              userName: 'Jose Reyes',
              userRole: 'Pharmacist',
              unreadNotifications: 3,
              navigationItems: items,
              selectedNavigationId: selected,
              onNavigationSelected: (id) => setState(() => selected = id),
              body: const Text('Body Content'),
            );
          },
        ),
      ),
    );

    // Verify header contents
    expect(find.text('Supreme Pharmacy · La Paz'), findsOneWidget);
    expect(find.text('PHM-000001 · La Paz, Iloilo City'), findsOneWidget);
    expect(find.text('Jose Reyes'), findsOneWidget);
    expect(find.text('Pharmacist'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // unread notifications badge

    // Verify sidebar shows Dashboard & Inventory, but hides Employees for Pharmacist
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Employees'), findsNothing);

    // Verify main body
    expect(find.text('Body Content'), findsOneWidget);
  });

  testWidgets('TabletFrame shows role-restricted items when role matches', (tester) async {
    const items = [
      TabletNavigationItem(id: 'dash', label: 'Dashboard', icon: Icons.dashboard),
      TabletNavigationItem(
        id: 'emp',
        label: 'Employees',
        icon: Icons.people,
        allowedRoles: ['owner'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TabletFrame(
          branchTitle: 'Supreme Pharmacy',
          userName: 'Maria Santos',
          userRole: 'Owner',
          navigationItems: items,
          selectedNavigationId: 'dash',
          onNavigationSelected: (_) {},
          body: const SizedBox(),
        ),
      ),
    );

    // Owner role sees Employees
    expect(find.text('Employees'), findsOneWidget);
  });
}
