// What the AI Listing Assistant suggests for the crop form. Every field is
// optional: if the AI gives a value we can't use, we drop that one field
// instead of trusting it. Tested in test/ai_listing_suggestion_test.dart.

import 'dart:convert';

import '../utils/constants.dart';

/// Form values suggested by the AI. null means "no usable suggestion".
class AiListingSuggestion {
  const AiListingSuggestion({
    this.crop,
    this.quantity,
    this.unit,
    this.price,
    this.description,
  });

  final String? crop;
  final double? quantity;
  final String? unit;
  final double? price;
  final String? description;

  /// True when the AI gave us nothing we can use.
  bool get isEmpty =>
      crop == null &&
      quantity == null &&
      unit == null &&
      price == null &&
      description == null;

  /// Reads the AI's JSON answer and keeps only valid values:
  /// - crop must be one of kCrops (local names like "kamatis" are converted)
  /// - unit must be one of kUnits
  /// - quantity and price must be numbers bigger than 0
  /// Throws FormatException if the answer is not JSON at all.
  factory AiListingSuggestion.fromJsonText(String text) {
    // Models sometimes wrap JSON in ```json ... ```, so remove that first.
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final decoded = jsonDecode(cleaned);
    // The Lite model sometimes answers with a list holding one object.
    final data = decoded is List && decoded.isNotEmpty
        ? decoded.first as Map<String, dynamic>
        : decoded as Map<String, dynamic>;

    return AiListingSuggestion(
      crop: _validCrop(data['crop']),
      quantity: _positiveNumber(data['quantity']),
      unit: kUnits.contains(data['unit']) ? data['unit'] as String : null,
      price: _positiveNumber(data['price']),
      description: _shortText(data['description']),
    );
  }

  static String? _validCrop(Object? value) {
    if (value is! String) return null;
    final word = value.trim().toLowerCase();
    for (final crop in kCrops) {
      if (crop.toLowerCase() == word) return crop;
    }
    return kLocalCropNames[word];
  }

  static double? _positiveNumber(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || number <= 0 || number > 100000) return null;
    return number;
  }

  static String? _shortText(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final text = value.trim();
    return text.length > 300 ? text.substring(0, 300) : text;
  }
}
