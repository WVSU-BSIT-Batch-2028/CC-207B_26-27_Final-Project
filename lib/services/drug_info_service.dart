import 'dart:convert';

import 'package:http/http.dart' as http;

/// Short reference text from the US FDA drug label of one medicine.
class DrugInfo {
  const DrugInfo({required this.genericName, this.uses, this.warnings});

  /// The generic name that was looked up (e.g. "amoxicillin").
  final String genericName;

  /// What the label says the medicine is used for, shortened.
  final String? uses;

  /// The label's warnings, shortened.
  final String? warnings;
}

/// Shown to the user when the reference service cannot be reached.
class DrugInfoException implements Exception {
  const DrugInfoException(this.message);

  final String message;
}

/// Names that differ between Philippine prescriptions and US FDA labels.
const Map<String, String> _usGenericNames = {
  'paracetamol': 'acetaminophen',
};

/// The name to search in the US label data: lower case, with the few
/// differing names swapped.
String usGenericName(String medicineName) {
  final name = medicineName.trim().toLowerCase();
  return _usGenericNames[name] ?? name;
}

/// A label field (a list of long texts) as one short, single-line text.
String? _shorten(Object? field, {int max = 320}) {
  if (field is! List || field.isEmpty) return null;

  var text = field.first.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  if (text.length > max) text = '${text.substring(0, max).trimRight()}...';
  return text;
}

/// Builds [DrugInfo] from one openFDA label, or null when the label has no
/// text we show. Plain function, so it can be unit tested.
DrugInfo? drugInfoFromLabel(String genericName, Map<String, dynamic> label) {
  final uses = _shorten(label['indications_and_usage']);
  final warnings =
      _shorten(label['warnings']) ?? _shorten(label['warnings_and_cautions']);
  if (uses == null && warnings == null) return null;

  return DrugInfo(genericName: genericName, uses: uses, warnings: warnings);
}

class _CacheEntry {
  _CacheEntry(this.at, this.info);

  final DateTime at;
  final DrugInfo? info;
}

/// Looks up reference information about a medicine in the openFDA drug label
/// API (https://open.fda.gov). REFERENCE ONLY: openFDA says not to rely on it
/// for medical care decisions, so screens must label it that way.
///
/// A free key raises the daily limit. Pass it when running the app:
///   flutter run --dart-define=OPENFDA_API_KEY=your_key
/// Never write the key in the code or commit it.
class DrugInfoService {
  DrugInfoService._();

  static final DrugInfoService instance = DrugInfoService._();

  static const String _apiKey = String.fromEnvironment('OPENFDA_API_KEY');
  static const Duration _cacheFor = Duration(hours: 12);

  final Map<String, _CacheEntry> _cache = {};

  /// The reference info for [medicineName], or null when the FDA has no label
  /// for that name (common for Philippine brand names).
  /// Throws [DrugInfoException] when the service cannot be reached.
  Future<DrugInfo?> fetch(String medicineName) async {
    final name = usGenericName(medicineName);
    if (name.isEmpty) return null;

    final cached = _cache[name];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheFor) {
      return cached.info;
    }

    final uri = Uri.https('api.fda.gov', '/drug/label.json', {
      'search': 'openfda.generic_name:"$name"',
      'limit': '1',
      if (_apiKey.isNotEmpty) 'api_key': _apiKey,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      DrugInfo? info;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final results = body is Map ? body['results'] : null;
        if (results is List && results.isNotEmpty && results.first is Map) {
          info = drugInfoFromLabel(
            name,
            Map<String, dynamic>.from(results.first as Map),
          );
        }
      } else if (response.statusCode != 404) {
        // 404 means "no matching label"; anything else is a service problem.
        throw const DrugInfoException(
          'The drug reference service is busy. Please try again later.',
        );
      }

      _cache[name] = _CacheEntry(DateTime.now(), info);
      return info;
    } on DrugInfoException {
      rethrow;
    } catch (_) {
      throw const DrugInfoException(
        "We couldn't reach the drug reference service. Check your connection and try again.",
      );
    }
  }
}