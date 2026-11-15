import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/tablet/tablet_navigation_item.dart';

void main() {
  group('TabletNavigationItem', () {
    test('filters visibility correctly by user role', () {
      const item = TabletNavigationItem(
        id: 'employees',
        label: 'Employees',
        icon: Icons.people,
        allowedRoles: ['owner'],
      );

      expect(item.isVisibleForRole('owner'), isTrue);
      expect(item.isVisibleForRole('Owner'), isTrue);
      expect(item.isVisibleForRole('pharmacist'), isFalse);
      expect(item.isVisibleForRole('staff'), isFalse);
    });

    test('default item is visible for all roles', () {
      const item = TabletNavigationItem(
        id: 'inventory',
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
      );

      expect(item.isVisibleForRole('owner'), isTrue);
      expect(item.isVisibleForRole('pharmacist'), isTrue);
      expect(item.isVisibleForRole('staff'), isTrue);
      expect(item.isVisibleForRole('admin'), isTrue);
    });
  });
}
