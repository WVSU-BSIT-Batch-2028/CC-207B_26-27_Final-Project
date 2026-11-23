import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/inventory_item.dart';
import 'package:meditech/providers/inventory_providers.dart';
import 'package:meditech/screens/pharmacy/inventory/inventory_screen.dart';
import 'package:meditech/services/inventory_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:meditech/widgets/theme/app_theme.dart';

class _FakeInventoryService implements InventoryService {
  List<InventoryItem> items;
  bool failLoad;

  _FakeInventoryService(this.items, {this.failLoad = false});

  @override
  Future<List<InventoryItem>> loadInventory() async {
    if (failLoad) throw const AppFailure('Failed to load inventory');
    return List.of(items);
  }

  @override
  Future<List<CatalogueMedicine>> loadCatalogue() async => [];

  @override
  Future<void> addItem({
    required String medicineId,
    required int stockQuantity,
    required double price,
    int lowStockThreshold = 10,
    DateTime? nearestExpiry,
  }) async {}

  @override
  Future<void> updateItem({
    required String itemId,
    int? stockQuantity,
    double? price,
    int? lowStockThreshold,
    DateTime? nearestExpiry,
    bool clearExpiry = false,
  }) async {}

  @override
  Future<void> setOutOfStock(List<String> itemIds) async {}

  @override
  Future<void> backInStock(Map<String, int> shelfCounts) async {}

  @override
  Future<void> setListingActive(List<String> itemIds, bool active) async {}
}

InventoryItem _testItem({
  required String id,
  required String brandName,
  required String genericName,
  int stock = 100,
  int held = 10,
  double price = 5.0,
  bool outOfStock = false,
  bool isRx = false,
  bool isActive = true,
}) {
  return InventoryItem(
    id: id,
    displayId: 'INV-000001',
    medicineId: 'med-$id',
    brandName: brandName,
    genericName: genericName,
    strength: '500 mg',
    dosageForm: 'Tablet',
    unit: 'tablet',
    isRx: isRx,
    stockQuantity: stock,
    heldQuantity: held,
    pricePerUnit: price,
    lowStockThreshold: 20,
    outOfStock: outOfStock,
    isActive: isActive,
    stockConfirmedAt: DateTime.now(),
  );
}

Widget _wrap(InventoryService service) {
  return ProviderScope(
    overrides: [
      inventoryServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SizedBox(
          width: 1200,
          height: 800,
          child: InventoryScreen(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('displays inventory items with stock and badges', (tester) async {
    final service = _FakeInventoryService([
      _testItem(id: '1', brandName: 'Biogesic', genericName: 'Paracetamol', stock: 240, held: 20),
      _testItem(id: '2', brandName: 'Amoxil', genericName: 'Amoxicillin', stock: 96, held: 14, isRx: true),
    ]);

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Amoxil'), findsOneWidget);
    expect(find.text('Paracetamol'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(find.text('Available'), findsNWidgets(2));
  });

  testWidgets('search narrows the inventory list', (tester) async {
    final service = _FakeInventoryService([
      _testItem(id: '1', brandName: 'Biogesic', genericName: 'Paracetamol'),
      _testItem(id: '2', brandName: 'Amoxil', genericName: 'Amoxicillin'),
    ]);

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Amoxil'), findsOneWidget);

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'amox');
    await tester.pumpAndSettle();

    expect(find.text('Amoxil'), findsOneWidget);
    expect(find.text('Biogesic'), findsNothing);
  });

  testWidgets('empty state displays when inventory has no items', (tester) async {
    final service = _FakeInventoryService([]);

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(
      find.text('No inventory entries yet. Add your first medicine.'),
      findsOneWidget,
    );
  });

  testWidgets('error state displays and retry re-fetches', (tester) async {
    final service = _FakeInventoryService([], failLoad: true);

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load inventory'), findsOneWidget);

    // Turn off failure and tap Retry
    service.failLoad = false;
    service.items = [
      _testItem(id: '1', brandName: 'Biogesic', genericName: 'Paracetamol'),
    ];

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
  });
}
