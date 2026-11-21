// Manual live check (NOT part of `flutter test`): reads public.places through the real Flutter repository.
//   flutter test --dart-define-from-file=env.json integration_live/live_places_check_test.dart
// Prints only counts/status, never credentials.
import 'package:flutter_test/flutter_test.dart';
import 'package:wvsu_wayfinder/core/config.dart';
import 'package:wvsu_wayfinder/data/faculty_repository.dart';
import 'package:wvsu_wayfinder/data/places_repository.dart';

void main() {
  final config = AppConfig.fromEnvironment();

  test('live: places search over Supabase REST', () async {
    expect(config.isLive, isTrue, reason: 'pass --dart-define-from-file=env.json');
    final repo = LivePlacesRepository(config);
    final byCode = await repo.search('cb 203'); // throws PlacesException on any non-200
    final byName = await repo.search('building');
    final all = await repo.list();
    // ignore: avoid_print
    print('LIVE places -> HTTP 200 on all 3 requests; "cb 203": ${byCode.length} rows, "building": ${byName.length} rows, list: ${all.length} rows');
  });

  test('live: faculty_directory unfiltered, then search by the returned full_name', () async {
    final repo = LiveFacultyRepository(config);
    final all = await repo.search(''); // throws PlacesException on any non-200
    // ignore: avoid_print
    print('LIVE faculty -> HTTP 200; unfiltered: ${all.length} rows');
    if (all.isNotEmpty) {
      final byName = await repo.search(all.first.fullName);
      // ignore: avoid_print
      print('LIVE faculty -> search "${all.first.fullName}": ${byName.length} rows; record_id=${byName.first.recordId}; department=${byName.first.department}');
    }
  });
}
