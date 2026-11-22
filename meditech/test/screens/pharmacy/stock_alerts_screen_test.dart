import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meditech/models/stock_alert_item.dart';
import 'package:meditech/providers/stock_alerts_providers.dart';
import 'package:meditech/screens/pharmacy/stock_alerts/stock_alerts_screen.dart';
import 'package:meditech/services/stock_alerts_service.dart';

class _FakeStockAlertsService implements StockAlertsService {
  @override
  Future<Map<StockAlertType, List<StockAlertItem>>> loadStockAlerts() async {
    return {
      StockAlertType.lowStock: [
        StockAlertItem(
          id: 'item-1',
          inventoryItemId: 'inv-1',
          medicineId: 'med-1',
          brandName: 'Norvasc',
          genericName: 'Amlodipine',
          strength: '5 mg',
          dosageForm: 'Tablet',
          unit: 'tablet',
          stockQuantity: 15,
          heldQuantity: 0,
          lowStockThreshold: 20,
          stockConfirmedAt: DateTime(2026, 10, 30, 8, 40),
          alertType: StockAlertType.lowStock,
        ),
      ],
      StockAlertType.outOfStock: [
        StockAlertItem(
          id: 'item-2',
          inventoryItemId: 'inv-2',
          medicineId: 'med-2',
          brandName: 'Glucophage',
          genericName: 'Metformin',
          strength: '500 mg',
          dosageForm: 'Tablet',
          unit: 'tablet',
          stockQuantity: 8,
          heldQuantity: 0,
          lowStockThreshold: 10,
          outOfStock: true,
          alertType: StockAlertType.outOfStock,
        ),
      ],
      StockAlertType.expiringSoon: [
        StockAlertItem(
          id: 'item-3',
          inventoryItemId: 'inv-3',
          medicineId: 'med-3',
          brandName: 'Myra-E',
          genericName: 'Vitamin E',
          strength: '400 IU',
          dosageForm: 'Capsule',
          unit: 'capsule',
          stockQuantity: 120,
          heldQuantity: 0,
          nearestExpiry: DateTime.now().add(const Duration(days: 45)),
          alertType: StockAlertType.expiringSoon,
        ),
      ],
      StockAlertType.notUpdated: [
        StockAlertItem(
          id: 'item-4',
          inventoryItemId: 'inv-4',
          medicineId: 'med-4',
          brandName: 'Biogesic',
          genericName: 'Paracetamol',
          strength: '500 mg',
          dosageForm: 'Tablet',
          unit: 'tablet',
          stockQuantity: 200,
          heldQuantity: 10,
          stockConfirmedAt: DateTime.now().subtract(const Duration(days: 10)),
          alertType: StockAlertType.notUpdated,
        ),
      ],
    };
  }
}

void main() {
  testWidgets('StockAlertsScreen renders tabs and category cards with counts',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockAlertsServiceProvider.overrideWithValue(_FakeStockAlertsService()),
        ],
        child: const MaterialApp(
          home: StockAlertsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Stock Alerts'), findsOneWidget);
    expect(find.text('Low stock'), findsWidgets);
    expect(find.text('Out of stock'), findsWidgets);
    expect(find.text('Expiring soon'), findsWidgets);
    expect(find.text('Not updated'), findsWidgets);

    // Initial low stock row
    expect(find.text('Norvasc 5 mg'), findsOneWidget);
    expect(find.text('Edit stock'), findsOneWidget);

    // Switch tab to Out of stock
    await tester.tap(find.text('Out of stock').first);
    await tester.pumpAndSettle();

    expect(find.text('Glucophage 500 mg'), findsOneWidget);
    expect(find.text('Back in stock'), findsOneWidget);
  });
}
