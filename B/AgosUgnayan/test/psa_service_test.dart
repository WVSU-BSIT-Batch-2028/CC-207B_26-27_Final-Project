// Unit tests for the PSA OpenSTAT import: the query we build, how PSA's
// answer is turned into prices, and the whole download with a fake PSA
// server (MockClient), so the tests need no internet.

import 'dart:convert';

import 'package:agosugnayan/services/psa_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A small copy of a real PSA table's metadata.
final Map<String, dynamic> meta = {
  'variables': [
    {
      'code': 'Geolocation',
      'text': 'Geolocation',
      'values': ['0', '52', '53'],
      'valueTexts': ['PHILIPPINES', '....Guimaras', '....Iloilo'],
    },
    {
      'code': 'Commodity',
      'text': 'Commodity',
      'values': ['0', '4', '9'],
      'valueTexts': [
        'Ampalaya fruit [Bitter gourd]',
        'Eggplant, long, purple',
        'Tomato',
      ],
    },
    {
      'code': 'Year',
      'text': 'Year',
      'values': ['14', '15', '16'],
      'valueTexts': ['2024', '2025', '2026'],
    },
    {
      'code': 'Period',
      'text': 'Period',
      'values': ['0', '1', '9', '10', '12'],
      'valueTexts': ['January', 'February', 'October', 'November', 'Annual'],
    },
  ],
};

/// PSA's answer: Tomato (code 9) in Iloilo (53) for some months.
final Map<String, dynamic> data = {
  'columns': [
    {'code': 'Geolocation'},
    {'code': 'Commodity'},
    {'code': 'Year'},
    {'code': 'Period'},
    {'code': 'FARMGATE PRICE'},
  ],
  'data': [
    {
      'key': ['53', '9', '16', '9'],
      'values': ['45.68'],
    }, // Oct 2026
    {
      'key': ['53', '9', '16', '10'],
      'values': ['.'],
    }, // Nov 2026: no price yet
    {
      'key': ['53', '9', '14', '0'],
      'values': ['30.00'],
    }, // Jan 2024: too old
    {
      'key': ['53', '0', '16', '9'],
      'values': ['55.10'],
    }, // Ampalaya Oct 2026
  ],
};

void main() {
  test('cleanPsaText removes the dots PSA adds', () {
    expect(cleanPsaText('....Iloilo'), 'Iloilo');
    expect(cleanPsaText(' Tomato. '), 'Tomato');
  });

  test('wantedMonths counts back from this month', () {
    final months = wantedMonths(DateTime(2026, 2, 15), 3);
    expect(months, {'2026-02', '2026-01', '2025-12'});
  });

  test('every crop has a PSA source, like the website', () {
    expect(kPsaFarmgate.length, 10); // the 10 crops PSA tables were mapped for
    expect(kPsaFarmgate['Ampalaya']!.name, 'Ampalaya fruit [Bitter gourd]');
  });

  test('buildPsaQuery picks Iloilo, our crops, the years and months only', () {
    final query = buildPsaQuery(meta, {'Tomato'}, {'2026'});
    final parts = {
      for (final part in query['query'] as List)
        (part as Map)['code']: (part['selection'] as Map)['values'],
    };
    expect(parts['Geolocation'], ['53']);
    expect(parts['Commodity'], ['9']);
    expect(parts['Year'], ['16']);
    // Every month, but not the "Annual" average.
    expect(parts['Period'], ['0', '1', '9', '10']);
  });

  test('parsePsaPrices keeps real prices in the wanted months', () {
    final records = parsePsaPrices(
      meta,
      data,
      {'Tomato': 'Tomato', 'Ampalaya fruit [Bitter gourd]': 'Ampalaya'},
      {'2026-10', '2026-11'},
    );
    expect(records.length, 2);
    expect(records[0].crop, 'Tomato');
    expect(records[0].month, '2026-10');
    expect(records[0].price, 45.68);
    expect(records[0].docId, 'Tomato_2026-10'); // same id as Add price
    expect(records[1].crop, 'Ampalaya');
  });

  test(
    'fetchFarmgate downloads each table once and lists missing crops',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        // A BOM at the start, like the real PSA answers.
        final body = request.method == 'GET' ? meta : data;
        return http.Response.bytes(
          utf8.encode('﻿${jsonEncode(body)}'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final result = await PsaService(client: client)
          .fetchFarmgate(monthsBack: 2, now: DateTime(2026, 11, 22));

      // 4 different tables: one GET each for the crop list, then one POST
      // only for the table that has crops in it (our fake table has only
      // Tomato, Eggplant and Ampalaya, which share table 05).
      expect(requests, 5);
      // Our fake table has Tomato and Ampalaya; both have an October price.
      expect(result.records.map((r) => r.crop).toSet(), {'Tomato', 'Ampalaya'});
      expect(result.missingCrops, contains('Cabbage'));
    },
  );

  test('fetchFarmgate gives a friendly error when PSA is down', () async {
    final client = MockClient((_) async => http.Response('down', 503));
    expect(
      () => PsaService(client: client).fetchFarmgate(),
      throwsA(
        predicate(
          (e) => e.toString().contains('Could not get prices from PSA'),
        ),
      ),
    );
  });
}
