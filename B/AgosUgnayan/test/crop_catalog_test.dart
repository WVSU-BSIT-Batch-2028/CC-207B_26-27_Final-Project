// Unit tests for the crop catalog and the price rules that use it:
// 71 unique crops in 6 categories, older prices keep their months, catalog
// prices fill the gaps, "Older price" and month-to-month changes.

import 'package:agosugnayan/models/price_record.dart';
import 'package:agosugnayan/services/price_service.dart';
import 'package:agosugnayan/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('71 crops, no duplicates', () {
    expect(kCropCatalog.length, 71);
    expect(kCrops.toSet().length, 71);
  });

  test('6 categories with 10/11/6/8/6/30 crops', () {
    expect(cropsIn(CropCategory.fruitVegetables).length, 10);
    expect(cropsIn(CropCategory.leafyVegetables).length, 11);
    expect(cropsIn(CropCategory.rootCrops).length, 6);
    expect(cropsIn(CropCategory.condiments).length, 8);
    expect(cropsIn(CropCategory.beans).length, 6);
    expect(cropsIn(CropCategory.fruits).length, 30);
  });

  test('the original 10 crops are still there (no copies)', () {
    for (final crop in [
      'Tomato',
      'Cabbage',
      'Carrots',
      'Eggplant',
      'Ampalaya',
      'Pechay',
      'Onion',
      'Squash',
      'Okra',
      'Kangkong',
    ]) {
      expect(kCrops.where((c) => c == crop).length, 1, reason: crop);
    }
  });

  test('older prices keep their original months', () {
    expect(cropInfo('Leeks')!.referenceMonth, '2025-01');
    expect(cropInfo('Patani')!.referenceMonth, '2025-12');
    expect(cropInfo('Tamarind')!.referenceMonth, '2026-03');
    expect(cropInfo('Lettuce')!.referenceMonth, '2026-06');
    expect(cropInfo('Lettuce')!.referencePrice, 250.00);
  });

  test('local names point to catalog crops', () {
    expect(kLocalCropNames['kamatis'], 'Tomato');
    expect(kLocalCropNames['sitaw'], 'Sitao');
    for (final crop in kLocalCropNames.values) {
      expect(kCrops, contains(crop));
    }
  });

  test('catalog prices fill gaps but a database price wins', () {
    final fromDatabase = [
      const PriceRecord(crop: 'Tomato', month: '2026-06', price: 40),
    ];
    final all = PriceService.withReferencePrices(fromDatabase);
    expect(all.length, 71); // Tomato from the database + 70 from the catalog
    final tomato = all.where((r) => r.crop == 'Tomato').single;
    expect(tomato.price, 40);
  });

  test('loading reference prices never overwrites a PSA import', () {
    final references = PriceService.referenceRecords();
    // "Get latest PSA prices" already saved Tomato and Onion for June 2026.
    final missing = PriceService.missingReferences(references, {
      'Tomato_2026-06',
      'Onion_2026-06',
    });
    expect(missing.length, 69);
    expect(missing.any((r) => r.crop == 'Tomato'), isFalse);
    expect(missing.any((r) => r.crop == 'Lettuce'), isTrue);
  });

  test('a price from before the newest month is an older price', () {
    final all = PriceService.withReferencePrices([]);
    expect(PriceService.newestMonth(all), '2026-06');
    expect(PriceService.isOlderPrice('Leeks', all), isTrue);
    expect(PriceService.isOlderPrice('Lettuce', all), isFalse);
  });

  test('the change is only worked out against the month just before', () {
    const may = PriceRecord(crop: 'Tomato', month: '2026-05', price: 30);
    const june = PriceRecord(crop: 'Tomato', month: '2026-06', price: 36);
    const january = PriceRecord(crop: 'Tomato', month: '2026-01', price: 20);
    expect(PriceService.monthlyChange('Tomato', [may, june]), 6);
    // January to June is not "since last month", so no change is shown.
    expect(PriceService.monthlyChange('Tomato', [january, june]), isNull);
    expect(PriceService.monthlyChange('Tomato', [june]), isNull);
  });
}
