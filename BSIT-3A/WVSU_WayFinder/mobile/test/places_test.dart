import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wvsu_wayfinder/core/config.dart';
import 'package:wvsu_wayfinder/core/search.dart';
import 'package:wvsu_wayfinder/data/models.dart';
import 'package:wvsu_wayfinder/data/places_repository.dart';

const live = AppConfig(supabaseUrl: 'https://example.supabase.co', supabasePublishableKey: 'sb_publishable_test');

Future<String> fixture() => File('assets/demo/places.json').readAsString();

void main() {
  group('room code normalization (same rule as web)', () {
    test('normalizes', () {
      for (final s in ['cb 203', 'CB-203', ' cb203 ', 'Cb.203']) {
        expect(normalizeRoomCode(s), 'CB203');
      }
    });
    test('recognizes codes vs names', () {
      expect(looksLikeRoomCode('cb 203'), isTrue);
      expect(looksLikeRoomCode('Registrar'), isFalse);
      expect(looksLikeRoomCode('cb'), isFalse);
    });
  });

  group('demo fixtures', () {
    test('mobile copy matches the web app fixture exactly (shared place IDs)', () async {
      final web = jsonDecode(await File('../src/data/demo/places.json').readAsString());
      final mobile = jsonDecode(await fixture());
      expect(mobile, equals(web));
    });

    test('known room: building and floor, same place ID as web', () async {
      final repo = DemoPlacesRepository(loader: fixture);
      final r = await repo.search('cb 203');
      expect(r, hasLength(1));
      expect(r.first.place.id, 'room-demo-cb-203');
      expect(r.first.place.floor, 2);
      expect(r.first.parent?.name, 'Demo College Building');
      expect(r.first.place.status, DataStatus.demo);
      expect(r.first.pointIsBuilding, isTrue);
    });

    test('unknown room returns nothing', () async {
      expect(await DemoPlacesRepository(loader: fixture).search('zz 999'), isEmpty);
    });
  });

  group('live repository (HTTP mocked)', () {
    test('queries PostgREST for verified rows by normalized code, publishable key as apikey only', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode([
              {
                'id': 'room-cb-203', 'kind': 'room', 'name': 'CB 203', 'short_name': null, 'room_code': 'CB203', 'floor': 2,
                'parent_id': 'bldg-cb', 'lng': null, 'lat': null, 'status': 'verified', 'source': 'x',
                'parent': {'id': 'bldg-cb', 'kind': 'building', 'name': 'CB', 'short_name': null, 'room_code': null, 'floor': null, 'parent_id': null, 'lng': 122.5, 'lat': 10.7, 'status': 'verified'},
              }
            ]),
            200);
      });
      final r = await LivePlacesRepository(live, client: client).search('cb 203');
      expect(seen.url.toString(), allOf(contains('/rest/v1/places?'), contains('status=eq.verified'), contains('room_code=eq.CB203')));
      expect(seen.headers['apikey'], 'sb_publishable_test');
      expect(seen.headers.containsKey('Authorization'), isFalse, reason: 'sb_publishable_ keys are not JWTs');
      expect(r.single.lat, 10.7); // room falls back to its building's point
      expect(r.single.place.status, DataStatus.verified);
    });

    test('empty result stays empty', () async {
      final repo = LivePlacesRepository(live, client: MockClient((_) async => http.Response('[]', 200)));
      expect(await repo.search('cb 203'), isEmpty);
    });

    test('HTTP error throws (no demo fallback in live mode)', () async {
      final repo = LivePlacesRepository(live, client: MockClient((_) async => http.Response('nope', 500)));
      expect(repo.search('cb 203'), throwsA(isA<PlacesException>()));
    });

    test('network error throws', () async {
      final repo = LivePlacesRepository(live, client: MockClient((_) async => throw http.ClientException('offline')));
      expect(repo.search('cb 203'), throwsA(isA<PlacesException>()));
    });

    test('createPlacesRepository: demo only when Supabase is not configured', () {
      expect(createPlacesRepository(const AppConfig()).isDemo, isTrue);
      expect(createPlacesRepository(live).isDemo, isFalse);
    });
  });
}
