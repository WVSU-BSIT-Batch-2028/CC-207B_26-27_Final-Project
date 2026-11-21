import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wvsu_wayfinder/core/config.dart';
import 'package:wvsu_wayfinder/data/faculty_repository.dart';
import 'package:wvsu_wayfinder/data/places_repository.dart';

import 'helpers.dart';

const live = AppConfig(supabaseUrl: 'https://example.supabase.co', supabasePublishableKey: 'sb_publishable_test');

void main() {
  group('LiveFacultyRepository (HTTP mocked)', () {
    test('named columns, published + verified rule, record_id as identifier', () async {
      late http.Request seen;
      final repo = LiveFacultyRepository(live, client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode([{'record_id': 7, 'full_name': 'Prof. Real', 'college_unit': 'College of ICT', 'college_code': 'CICT', 'department': 'Computing', 'position_title': 'Instructor I'}]), 200);
      }));
      final rows = await repo.search('real');
      final url = Uri.decodeFull(seen.url.toString());
      expect(url, contains('/rest/v1/faculty_directory?select=record_id,full_name,college_unit,college_code,department,position_title&is_published=eq.true&review_status=eq.verified'));
      expect(url, contains('full_name=ilike.*real*'));
      expect(url, isNot(contains('select=*')));
      expect(seen.headers['apikey'], 'sb_publishable_test');
      expect(rows.single.recordId, '7');
      expect(rows.single.positionTitle, 'Instructor I');
      expect(rows.single.officePlaceId, isNull, reason: 'the live table has no office link column');
    });

    test('HTTP error throws (no demo fallback in live mode)', () async {
      final repo = LiveFacultyRepository(live, client: MockClient((_) async => http.Response('{}', 404)));
      expect(repo.search(''), throwsA(isA<PlacesException>()));
    });
  });

  test('demo repository applies the same publication rule', () async {
    final repo = DemoFacultyRepository(loader: () async => fixture('faculty.json'));
    final names = (await repo.search('')).map((f) => f.fullName);
    expect(names, contains('Demo Prof. Maria Mapped'));
    expect(names.where((n) => n.contains('Hidden')), isEmpty);
    expect(await repo.get('demo-fd-5'), isNull);
  });
}
