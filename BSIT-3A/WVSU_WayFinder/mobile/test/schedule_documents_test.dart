import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wvsu_wayfinder/data/schedule_documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp(
      'schedule-documents-test-',
    );
  });
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'upload remains available even with no detected classes or original picker file',
    () async {
      final source = File('${temporary.path}/original.png');
      await source.writeAsBytes([1, 2, 3]);
      final store = ScheduleDocumentStore(directory: () async => temporary);
      final document = await store.addFile(
        source.path,
        name: 'My schedule.png',
      );
      await source.delete();
      expect(await File(document.path).readAsBytes(), [1, 2, 3]);
      expect(document.toJson()['storage_path'], '${document.id}.png');
      expect(document.toJson()['uploaded_at'], endsWith('Z'));
      final reopened = ScheduleDocumentStore(directory: () async => temporary);
      await reopened.load();
      expect(reopened.uploads.single.id, document.id);
      expect(reopened.uploads.single.name, 'My schedule.png');
      expect(reopened.uploads.single.text, '');
      expect(await File(reopened.uploads.single.path).exists(), isTrue);
    },
  );

  test(
    'concurrent file and corrected OCR writes keep both documents after restart',
    () async {
      final source = File('${temporary.path}/original.pdf');
      await source.writeAsString('synthetic file');
      final store = ScheduleDocumentStore(directory: () async => temporary);
      final first = await store.addFile(source.path, name: 'first.pdf');
      await Future.wait([
        store.addFile(source.path, name: 'second.pdf'),
        store.updateText(
          first.id,
          'Subject | Day | Time\nWeb Systems | Mon | 08:00-09:00',
        ),
      ]);
      final reopened = ScheduleDocumentStore(directory: () async => temporary);
      await reopened.load();
      expect(reopened.uploads, hasLength(2));
      expect(reopened.byId(first.id)!.text, contains('Web Systems'));
    },
  );

  test(
    'a transient startup load failure can be retried without losing uploads',
    () async {
      final source = File('${temporary.path}/original.pdf');
      await source.writeAsString('synthetic file');
      final original = ScheduleDocumentStore(directory: () async => temporary);
      final document = await original.addFile(
        source.path,
        name: 'schedule.pdf',
      );
      var fail = true;
      final reopened = ScheduleDocumentStore(
        directory: () async {
          if (fail) {
            throw const FileSystemException('Temporary directory failure');
          }
          return temporary;
        },
      );
      await reopened.loadForDisplay();
      expect(reopened.error, isNotNull);
      expect(reopened.uploads, isEmpty);
      fail = false;
      await reopened.load();
      expect(reopened.error, isNull);
      expect(reopened.uploads.single.id, document.id);
    },
  );

  test(
    'oversized selection is rejected without creating an upload record',
    () async {
      final source = File('${temporary.path}/oversized.pdf');
      final handle = await source.open(mode: FileMode.write);
      await handle.truncate(20 * 1024 * 1024 + 1);
      await handle.close();
      final store = ScheduleDocumentStore(directory: () async => temporary);
      await expectLater(
        store.addFile(source.path, name: 'large.pdf'),
        throwsFormatException,
      );
      expect(store.uploads, isEmpty);
    },
  );
}
