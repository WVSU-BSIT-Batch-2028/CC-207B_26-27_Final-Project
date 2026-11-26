// Every crop the app supports, grouped in 6 categories, with:
// - the Wikipedia article used for its sample photo,
// - a PSA farmgate reference price (pesos per kg) and the month it is from,
// - local names the AI assistant understands (e.g. "kamatis" = Tomato).
//
// To add a crop: add one CropInfo line to the right category below. Keep the
// month exactly as PSA published it; the app labels prices older than the
// newest month as "Older price", so an old price is never shown as current.

import 'package:flutter/material.dart';

/// The 6 groups crops are shown in (pickers, filters, Prices).
enum CropCategory {
  fruitVegetables('Fruit vegetables', Icons.eco_outlined),
  leafyVegetables('Leafy vegetables', Icons.grass_outlined),
  rootCrops('Root crops', Icons.spa_outlined),
  condiments('Condiments', Icons.local_fire_department_outlined),
  beans('Beans', Icons.grain_outlined),
  fruits('Fruits', Icons.apple_outlined);

  const CropCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One crop and its reference data.
class CropInfo {
  const CropInfo(
    this.name,
    this.category,
    this.wikipedia,
    this.referencePrice,
    this.referenceMonth, {
    this.localNames = const [],
  });

  /// Shown in the app, e.g. "Siling labuyo".
  final String name;
  final CropCategory category;

  /// English Wikipedia article for the sample photo, e.g. "Bok choy".
  final String wikipedia;

  /// PSA farmgate reference price in pesos per kg.
  final double referencePrice;

  /// The month that price is from, as "yyyy-MM", e.g. "2026-06".
  final String referenceMonth;

  /// Hiligaynon / Filipino names, lower case, for the AI assistant.
  final List<String> localNames;
}

const _fv = CropCategory.fruitVegetables;
const _lv = CropCategory.leafyVegetables;
const _rc = CropCategory.rootCrops;
const _co = CropCategory.condiments;
const _be = CropCategory.beans;
const _fr = CropCategory.fruits;

/// All 71 crops. Prices: PSA farmgate, Iloilo Province (given by the team,
/// Nov 2026). Months older than June 2026 are kept as published.
const List<CropInfo> kCropCatalog = [
  // Fruit vegetables (10)
  CropInfo(
    'Ampalaya',
    _fv,
    'Momordica charantia',
    43.55,
    '2026-06',
    localNames: ['amargoso', 'paliya'],
  ),
  CropInfo(
    'Banana blossom',
    _fv,
    'Banana',
    20.00,
    '2026-06',
    localNames: ['puso ng saging', 'puso sang saging'],
  ),
  CropInfo('Chayote', _fv, 'Chayote', 42.58, '2026-06', localNames: ['sayote']),
  CropInfo(
    'Cucumber',
    _fv,
    'Cucumber',
    25.55,
    '2026-06',
    localNames: ['pipino'],
  ),
  CropInfo(
    'Eggplant',
    _fv,
    'Eggplant',
    39.13,
    '2026-06',
    localNames: ['talong'],
  ),
  CropInfo('Okra', _fv, 'Okra', 46.24, '2026-06', localNames: ['okra']),
  CropInfo(
    'Patola',
    _fv,
    'Luffa acutangula',
    25.04,
    '2026-06',
    localNames: ['patola'],
  ),
  CropInfo(
    'Squash',
    _fv,
    'Calabaza',
    23.12,
    '2026-06',
    localNames: ['kalabasa'],
  ),
  CropInfo('Tomato', _fv, 'Tomato', 38.81, '2026-06', localNames: ['kamatis']),
  CropInfo(
    'Upo',
    _fv,
    'Calabash',
    14.32,
    '2026-06',
    localNames: ['upo', 'tabayag'],
  ),

  // Leafy vegetables (11)
  CropInfo(
    'Alugbati',
    _lv,
    'Basella alba',
    42.40,
    '2026-06',
    localNames: ['alugbati', 'libato'],
  ),
  CropInfo(
    'Cabbage',
    _lv,
    'Cabbage',
    30.00,
    '2026-06',
    localNames: ['repolyo'],
  ),
  CropInfo(
    'Camote tops',
    _lv,
    'Sweet potato',
    28.01,
    '2026-06',
    localNames: ['talbos ng kamote', 'talbos sang kamote'],
  ),
  CropInfo(
    'Cauliflower',
    _lv,
    'Cauliflower',
    120.00,
    '2026-06',
    localNames: ['koliflor'],
  ),
  CropInfo(
    'Chili leaves',
    _lv,
    'Capsicum annuum',
    100.00,
    '2026-06',
    localNames: ['dahon ng sili', 'dahon sang sili'],
  ),
  CropInfo(
    'Kangkong',
    _lv,
    'Ipomoea aquatica',
    15.83,
    '2026-06',
    localNames: ['kangkong'],
  ),
  CropInfo(
    'Lettuce',
    _lv,
    'Lettuce',
    250.00,
    '2026-06',
    localNames: ['litsugas'],
  ),
  CropInfo(
    'Malunggay',
    _lv,
    'Moringa oleifera',
    40.00,
    '2026-06',
    localNames: ['malunggay', 'kalamunggay'],
  ),
  CropInfo(
    'Mustard',
    _lv,
    'Brassica juncea',
    100.00,
    '2026-06',
    localNames: ['mustasa'],
  ),
  CropInfo('Pechay', _lv, 'Bok choy', 65.00, '2026-06', localNames: ['petsay']),
  CropInfo(
    'Saluyot',
    _lv,
    'Corchorus olitorius',
    34.12,
    '2026-06',
    localNames: ['saluyot'],
  ),

  // Root crops (6)
  CropInfo(
    'Camote',
    _rc,
    'Sweet potato',
    32.60,
    '2026-06',
    localNames: ['kamote'],
  ),
  CropInfo('Carrots', _rc, 'Carrot', 40.00, '2026-06', localNames: ['karot']),
  CropInfo(
    'Cassava',
    _rc,
    'Cassava',
    18.39,
    '2026-06',
    localNames: ['kamoteng kahoy', 'balinghoy'],
  ),
  CropInfo(
    'Gabi',
    _rc,
    'Taro',
    20.00,
    '2026-06',
    localNames: ['gabi', 'gaway'],
  ),
  CropInfo('Radish', _rc, 'Radish', 21.46, '2026-06', localNames: ['labanos']),
  CropInfo(
    'Ubi',
    _rc,
    'Dioscorea alata',
    25.00,
    '2026-06',
    localNames: ['ubi'],
  ),

  // Condiments (8)
  CropInfo(
    'Bell pepper',
    _co,
    'Bell pepper',
    85.80,
    '2026-06',
    localNames: ['atsal'],
  ),
  CropInfo(
    'Garlic',
    _co,
    'Garlic',
    65.00,
    '2026-06',
    localNames: ['bawang', 'ahos'],
  ),
  CropInfo('Ginger', _co, 'Ginger', 100.00, '2026-06', localNames: ['luya']),
  CropInfo('Leeks', _co, 'Leek', 40.00, '2025-01', localNames: ['leeks']),
  CropInfo(
    'Onion',
    _co,
    'Red onion',
    50.00,
    '2026-06',
    localNames: ['sibuyas'],
  ),
  CropInfo('Shallot', _co, 'Shallot', 50.00, '2026-06', localNames: ['lasona']),
  CropInfo(
    'Siling labuyo',
    _co,
    'Siling labuyo',
    91.42,
    '2026-06',
    localNames: ['sili', 'katumbal'],
  ),
  CropInfo(
    'Spring onion',
    _co,
    'Scallion',
    181.56,
    '2026-06',
    localNames: ['dahon ng sibuyas', 'sibuyas dahon'],
  ),

  // Beans (6)
  CropInfo(
    'Kadios',
    _be,
    'Pigeon pea',
    91.96,
    '2026-06',
    localNames: ['kadyos', 'kadios'],
  ),
  CropInfo(
    'Mongo',
    _be,
    'Mung bean',
    70.00,
    '2026-06',
    localNames: ['monggo', 'balatong'],
  ),
  CropInfo(
    'Patani',
    _be,
    'Lima bean',
    50.00,
    '2025-12',
    localNames: ['patani'],
  ),
  CropInfo(
    'Sigarilyas',
    _be,
    'Winged bean',
    45.00,
    '2026-06',
    localNames: ['sigarilyas', 'sigadilyas'],
  ),
  CropInfo(
    'Sitao',
    _be,
    'Yardlong bean',
    44.60,
    '2026-06',
    localNames: ['sitaw', 'hantak'],
  ),
  CropInfo(
    'Snap beans',
    _be,
    'Green bean',
    28.64,
    '2026-06',
    localNames: ['baguio beans', 'habitswelas'],
  ),

  // Fruits (30)
  CropInfo('Atis', _fr, 'Sugar-apple', 63.13, '2026-06', localNames: ['atis']),
  CropInfo(
    'Avocado',
    _fr,
    'Avocado',
    43.80,
    '2026-06',
    localNames: ['abokado'],
  ),
  CropInfo('Banana', _fr, 'Banana', 14.03, '2026-06', localNames: ['saging']),
  CropInfo(
    'Calamansi',
    _fr,
    'Calamansi',
    34.31,
    '2026-06',
    localNames: ['kalamansi', 'limonsito'],
  ),
  CropInfo(
    'Camachile',
    _fr,
    'Pithecellobium dulce',
    94.84,
    '2026-05',
    localNames: ['kamatsile'],
  ),
  CropInfo(
    'Canistel',
    _fr,
    'Pouteria campechiana',
    10.00,
    '2025-12',
    localNames: ['tiesa'],
  ),
  CropInfo('Chico', _fr, 'Sapodilla', 30.00, '2026-06', localNames: ['tsiko']),
  CropInfo(
    'Dragon fruit',
    _fr,
    'Pitaya',
    150.00,
    '2026-06',
    localNames: ['dragon fruit'],
  ),
  CropInfo(
    'Duhat',
    _fr,
    'Syzygium cumini',
    50.00,
    '2026-06',
    localNames: ['duhat', 'lomboy'],
  ),
  CropInfo('Durian', _fr, 'Durian', 50.00, '2025-12', localNames: ['durian']),
  CropInfo(
    'Guava',
    _fr,
    'Guava',
    35.00,
    '2025-12',
    localNames: ['bayabas', 'bayabas'],
  ),
  CropInfo(
    'Guyabano',
    _fr,
    'Soursop',
    22.07,
    '2026-06',
    localNames: ['guyabano', 'atis-a'],
  ),
  CropInfo(
    'Honeydew melon',
    _fr,
    'Honeydew (melon)',
    39.50,
    '2026-04',
    localNames: ['melon'],
  ),
  CropInfo(
    'Lanzones',
    _fr,
    'Lansium parasiticum',
    40.00,
    '2026-01',
    localNames: ['lansones'],
  ),
  CropInfo('Lemon', _fr, 'Lemon', 20.00, '2026-05', localNames: ['lemon']),
  CropInfo(
    'Mandarin',
    _fr,
    'Mandarin orange',
    40.00,
    '2026-04',
    localNames: ['dalandan', 'sintones'],
  ),
  CropInfo(
    'Mango',
    _fr,
    'Mango',
    63.23,
    '2026-06',
    localNames: ['mangga', 'paho'],
  ),
  CropInfo(
    'Mangosteen',
    _fr,
    'Purple mangosteen',
    45.00,
    '2026-04',
    localNames: ['mangostin'],
  ),
  CropInfo(
    'Marang',
    _fr,
    'Artocarpus odoratissimus',
    45.00,
    '2026-06',
    localNames: ['marang'],
  ),
  CropInfo(
    'Orange',
    _fr,
    'Orange (fruit)',
    39.67,
    '2026-05',
    localNames: ['kahel'],
  ),
  CropInfo('Papaya', _fr, 'Papaya', 21.08, '2026-06', localNames: ['kapayas']),
  CropInfo(
    'Pineapple',
    _fr,
    'Pineapple',
    16.00,
    '2026-06',
    localNames: ['pinya'],
  ),
  CropInfo(
    'Pomelo',
    _fr,
    'Pomelo',
    30.00,
    '2026-06',
    localNames: ['suha', 'lukban'],
  ),
  CropInfo(
    'Rambutan',
    _fr,
    'Rambutan',
    39.00,
    '2026-06',
    localNames: ['rambutan'],
  ),
  CropInfo(
    'Ripe jackfruit',
    _fr,
    'Jackfruit',
    30.00,
    '2026-06',
    localNames: ['langka', 'nangka'],
  ),
  CropInfo(
    'Sineguelas',
    _fr,
    'Spondias purpurea',
    56.24,
    '2026-05',
    localNames: ['siniguelas', 'sirgwelas'],
  ),
  CropInfo(
    'Starapple',
    _fr,
    'Chrysophyllum cainito',
    50.00,
    '2026-05',
    localNames: ['kaimito'],
  ),
  CropInfo(
    'Tamarind',
    _fr,
    'Tamarind',
    40.00,
    '2026-03',
    localNames: ['sampalok', 'sambag'],
  ),
  CropInfo(
    'Tambis',
    _fr,
    'Syzygium aqueum',
    40.00,
    '2026-06',
    localNames: ['tambis'],
  ),
  CropInfo(
    'Watermelon',
    _fr,
    'Watermelon',
    50.00,
    '2026-05',
    localNames: ['pakwan', 'sandiya'],
  ),
];

/// Quick lookup by crop name.
final Map<String, CropInfo> kCropsByName = {
  for (final crop in kCropCatalog) crop.name: crop,
};

/// The crop's info, or null for a name that is not in the catalog.
CropInfo? cropInfo(String name) => kCropsByName[name];

/// The crops of one category, in catalog (A-Z) order.
List<String> cropsIn(CropCategory category) => [
  for (final crop in kCropCatalog)
    if (crop.category == category) crop.name,
];
