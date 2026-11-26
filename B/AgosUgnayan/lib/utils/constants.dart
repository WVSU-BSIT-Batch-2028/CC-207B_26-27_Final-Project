// Fixed lists used by dropdowns, filters and the AI assistant: the crops we
// support, the units farmers sell in, and the towns of Iloilo Province.
// To add a town, add one line to the list. Crops live in crop_catalog.dart.

import 'crop_catalog.dart';

export 'crop_catalog.dart';

/// The crops farmers can list (all 71 from the crop catalog, by category).
/// Edit the crops in lib/utils/crop_catalog.dart.
final List<String> kCrops = [for (final crop in kCropCatalog) crop.name];

/// Local (Hiligaynon / Filipino) names, so the AI assistant understands notes
/// like "50 kilos kamatis". Key = local word, value = crop in [kCrops].
final Map<String, String> kLocalCropNames = {
  for (final crop in kCropCatalog)
    for (final local in crop.localNames) local: crop.name,
};

/// Units a farmer can sell in.
const List<String> kUnits = ['kg', 'sack', 'bundle', 'piece'];

/// Towns (and the two cities) of Iloilo Province. Leon is first because the
/// app starts there.
const List<String> kTowns = [
  'Leon',
  'Ajuy',
  'Alimodian',
  'Anilao',
  'Badiangan',
  'Balasan',
  'Banate',
  'Barotac Nuevo',
  'Barotac Viejo',
  'Batad',
  'Bingawan',
  'Cabatuan',
  'Calinog',
  'Carles',
  'Concepcion',
  'Dingle',
  'Dueñas',
  'Dumangas',
  'Estancia',
  'Guimbal',
  'Igbaras',
  'Iloilo City',
  'Janiuay',
  'Lambunao',
  'Leganes',
  'Lemery',
  'Maasin',
  'Miagao',
  'Mina',
  'New Lucena',
  'Oton',
  'Passi City',
  'Pavia',
  'Pototan',
  'San Dionisio',
  'San Enrique',
  'San Joaquin',
  'San Miguel',
  'San Rafael',
  'Santa Barbara',
  'Sara',
  'Tigbauan',
  'Tubungan',
  'Zarraga',
];

/// How many items the Marketplace loads per page.
const int kPageSize = 20;

/// Where reference prices come from. Shown next to every price, because we
/// never claim prices are "live".
const String kPriceSource = 'PSA farmgate, Iloilo Province';
