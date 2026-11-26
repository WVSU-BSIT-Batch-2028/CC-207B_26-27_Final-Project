// One monthly reference price for one crop, e.g. Tomato, Aug 2026, ₱45.00/kg.
// Saved in Firestore at prices/{crop}_{yyyy-MM}.

import 'firestore_date.dart';

/// A reference price entered by the admin from PSA farmgate data.
class PriceRecord {
  const PriceRecord({
    required this.crop,
    required this.month,
    required this.price,
  });

  final String crop;
  final String month; // "2026-08"
  final double price; // pesos per kg

  /// The document id: one price per crop per month, so saving the same month
  /// again replaces the old price instead of adding a duplicate.
  String get docId => '${crop}_$month';

  factory PriceRecord.fromMap(Map<String, dynamic> data) {
    return PriceRecord(
      crop: data['crop'] as String? ?? '',
      month: data['month'] as String? ?? '',
      price: readDouble(data['price']),
    );
  }

  /// Used for Firestore and for the offline copy in shared_preferences.
  Map<String, dynamic> toMap() => {
    'crop': crop,
    'month': month,
    'price': price,
  };
}
