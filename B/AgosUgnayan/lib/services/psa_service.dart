// Gets real monthly farmgate prices for Iloilo Province from PSA OpenSTAT
// (Philippine Statistics Authority), the same free source and crop mapping
// the AgosUgnayan website uses (scripts/import-psa-prices.ts). No account or
// API key is needed. The admin runs it with "Get latest PSA prices".
//
// How the PSA API works (it is a "PxWeb" API):
// 1. GET a table's metadata: the lists of places, crops, years and months,
//    each with a code (e.g. "53") and a text (e.g. "....Iloilo").
// 2. POST a query with the codes we want; PSA answers with one row per
//    place + crop + year + month and its price.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/price_record.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';
import '../utils/format.dart';

/// Where one crop's price is in PSA OpenSTAT: the table and the crop's name
/// in that table.
class PsaSource {
  const PsaSource(this.table, this.name);

  final String table;
  final String name;
}

/// Our crops and their PSA farmgate tables (copied from the website's
/// supabase/seed.sql, so both apps read exactly the same numbers).
const Map<String, PsaSource> kPsaFarmgate = {
  'Tomato': PsaSource('NFG/0032M4AFN05.px', 'Tomato'),
  'Cabbage': PsaSource('NFG/0032M4AFN06.px', 'Cabbage'),
  'Carrots': PsaSource('NFG/0032M4AFN02.px', 'Carrot'),
  'Eggplant': PsaSource('NFG/0032M4AFN05.px', 'Eggplant, long, purple'),
  'Ampalaya': PsaSource('NFG/0032M4AFN05.px', 'Ampalaya fruit [Bitter gourd]'),
  'Pechay': PsaSource('NFG/0032M4AFN06.px', 'Pechay, native'),
  'Onion': PsaSource('NFG/0032M4AFN04.px', 'Onion, red creole (Bermuda red)'),
  'Squash': PsaSource('NFG/0032M4AFN05.px', 'Squash fruit'),
  'Okra': PsaSource('NFG/0032M4AFN05.px', "Okra [Lady's finger]"),
  'Kangkong': PsaSource('NFG/0032M4AFN06.px', 'Kangkong [Swamp cabbage]'),
};

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The result of one PSA download.
class PsaResult {
  const PsaResult(this.records, this.missingCrops);

  /// One price per crop per month that PSA has.
  final List<PriceRecord> records;

  /// Crops PSA had no price for in these months.
  final List<String> missingCrops;
}

/// Downloads farmgate prices from PSA OpenSTAT.
class PsaService {
  PsaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://openstat.psa.gov.ph/PXWeb/api/v1/en/DB/2M/';
  static const _province = 'Iloilo'; // PSA's name for Iloilo Province
  static const _timeout = Duration(seconds: 30);

  /// Prices for every crop in [kPsaFarmgate] for the last [monthsBack]
  /// months. Throws an [AppException] with a friendly message if PSA can't
  /// be reached.
  Future<PsaResult> fetchFarmgate({int monthsBack = 24, DateTime? now}) async {
    final wanted = wantedMonths(now ?? DateTime.now(), monthsBack);
    final years = {for (final month in wanted) month.substring(0, 4)};

    // Group crops by table, so each PSA table is downloaded only once.
    final cropsByTable = <String, List<String>>{};
    kPsaFarmgate.forEach((crop, source) {
      cropsByTable.putIfAbsent(source.table, () => []).add(crop);
    });

    final records = <PriceRecord>[];
    try {
      for (final entry in cropsByTable.entries) {
        final crops = entry.value;
        final nameToCrop = {
          for (final crop in crops)
            cleanPsaText(kPsaFarmgate[crop]!.name): crop,
        };
        final meta = await _getJson(entry.key);
        // Only ask for crop names this table really has. If PSA renamed a
        // crop, that crop is listed as missing instead of failing it all.
        final names = psaCommodityNames(meta)
            .intersection(nameToCrop.keys.toSet());
        if (names.isEmpty) continue;
        final query = buildPsaQuery(meta, names, years);
        final data = await _postJson(entry.key, query);
        records.addAll(parsePsaPrices(meta, data, nameToCrop, wanted));
      }
    } on AppException {
      rethrow;
    } catch (e, stack) {
      AppLogger.error('PSA download failed', e, stack);
      throw const AppException(
        'Could not get prices from PSA OpenSTAT. Check your internet and '
        'try again later.',
      );
    }
    final found = {for (final record in records) record.crop};
    final missing = [
      for (final crop in kPsaFarmgate.keys)
        if (!found.contains(crop)) crop,
    ];
    return PsaResult(records, missing);
  }

  Future<Map<String, dynamic>> _getJson(String table) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl$table'))
        .timeout(_timeout);
    return _decode(response, table);
  }

  /// Sent as text/plain on purpose: browsers send that without asking PSA
  /// for permission first (a "preflight"), which PSA's server doesn't answer
  /// fully. PSA reads the JSON either way.
  Future<Map<String, dynamic>> _postJson(
    String table,
    Map<String, dynamic> query,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$table'),
          headers: {'Content-Type': 'text/plain'},
          body: jsonEncode(query),
        )
        .timeout(_timeout);
    return _decode(response, table);
  }

  Map<String, dynamic> _decode(http.Response response, String table) {
    if (response.statusCode != 200) {
      throw Exception('$table: PSA returned HTTP ${response.statusCode}');
    }
    // PSA starts its answers with an invisible "BOM" character; remove it.
    final text = utf8.decode(response.bodyBytes).replaceFirst('﻿', '');
    return jsonDecode(text) as Map<String, dynamic>;
  }
}

/// PSA writes places like "....Iloilo" and crops like "Tomato."; this
/// removes the dots and spaces so names can be compared.
String cleanPsaText(String text) => text.replaceAll('.', '').trim();

/// The month keys ("2026-11", "2026-10", ...) of the last [monthsBack]
/// months, counting the month of [now].
Set<String> wantedMonths(DateTime now, int monthsBack) {
  return {
    for (var i = 0; i < monthsBack; i++)
      monthKeyOf(DateTime(now.year, now.month - i)),
  };
}

/// The crop names (cleaned) that a PSA table has, from its [meta]data.
Set<String> psaCommodityNames(Map<String, dynamic> meta) {
  return {
    for (final text in _variable(meta, 'commodity').texts) cleanPsaText(text),
  };
}

/// Builds the PSA query: Iloilo, the crops in [psaNames], the [years], and
/// every month (not the "Annual" average). [meta] is the table's metadata.
Map<String, dynamic> buildPsaQuery(
  Map<String, dynamic> meta,
  Set<String> psaNames,
  Set<String> years,
) {
  Map<String, dynamic> pick(String name, bool Function(String text) keep) {
    final variable = _variable(meta, name);
    final codes = [
      for (var i = 0; i < variable.codes.length; i++)
        if (keep(cleanPsaText(variable.texts[i]))) variable.codes[i],
    ];
    if (codes.isEmpty) throw Exception('PSA table has no matching "$name"');
    return {
      'code': variable.code,
      'selection': {'filter': 'item', 'values': codes},
    };
  }

  return {
    'query': [
      pick('geolocation', (text) => text == PsaService._province),
      pick('commodity', psaNames.contains),
      pick('year', years.contains),
      pick('period', _monthNames.contains),
    ],
    'response': {'format': 'json'},
  };
}

/// Turns PSA's answer into price records. [nameToCrop] maps PSA crop names
/// (cleaned) to our crop names. Months PSA has no price for ("." or "..")
/// and months outside [wanted] are skipped.
List<PriceRecord> parsePsaPrices(
  Map<String, dynamic> meta,
  Map<String, dynamic> data,
  Map<String, String> nameToCrop,
  Set<String> wanted,
) {
  final columns = [
    for (final column in data['columns'] as List)
      (column as Map<String, dynamic>)['code'] as String,
  ];
  // Turns a code in column [index] back into its text, e.g. "4" -> "Tomato".
  String textOf(int index, String code) {
    final variable = _variableByCode(meta, columns[index]);
    final position = variable.codes.indexOf(code);
    return position < 0 ? code : cleanPsaText(variable.texts[position]);
  }

  final records = <PriceRecord>[];
  for (final row in data['data'] as List) {
    final key = ((row as Map<String, dynamic>)['key'] as List).cast<String>();
    final value = (row['values'] as List).first as String;
    final price = double.tryParse(value);
    if (price == null || price <= 0) continue; // no price that month

    final crop = nameToCrop[textOf(1, key[1])];
    final year = textOf(2, key[2]);
    final monthNumber = _monthNames.indexOf(textOf(3, key[3])) + 1;
    if (crop == null || monthNumber == 0) continue;

    final month = '$year-${monthNumber.toString().padLeft(2, '0')}';
    if (!wanted.contains(month)) continue;
    records.add(PriceRecord(crop: crop, month: month, price: price));
  }
  return records;
}

/// One variable (column) of a PSA table: its code, value codes and texts.
class _PsaVariable {
  const _PsaVariable(this.code, this.codes, this.texts);

  final String code;
  final List<String> codes;
  final List<String> texts;
}

_PsaVariable _variable(Map<String, dynamic> meta, String name) {
  for (final item in meta['variables'] as List) {
    final variable = item as Map<String, dynamic>;
    if ((variable['text'] as String).toLowerCase().contains(name)) {
      return _toVariable(variable);
    }
  }
  throw Exception('PSA table has no "$name" column');
}

_PsaVariable _variableByCode(Map<String, dynamic> meta, String code) {
  for (final item in meta['variables'] as List) {
    final variable = item as Map<String, dynamic>;
    if (variable['code'] == code) return _toVariable(variable);
  }
  throw Exception('PSA answer has an unknown column "$code"');
}

_PsaVariable _toVariable(Map<String, dynamic> variable) => _PsaVariable(
  variable['code'] as String,
  (variable['values'] as List).cast<String>(),
  (variable['valueTexts'] as List).cast<String>(),
);
