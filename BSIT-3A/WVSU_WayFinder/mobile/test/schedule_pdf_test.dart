import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wvsu_wayfinder/data/schedule_import.dart';

// A small, synthetic PDF with column-major content streams, like table exports.
// No student document or personal data is needed for this native extraction test.
List<int> tablePdf({bool grid = false}) {
  final stream = StringBuffer('BT /F1 12 Tf\n');
  void text(int x, int y, String value) =>
      stream.writeln('1 0 0 1 $x $y Tm ($value) Tj');
  if (grid) {
    text(80, 740, 'Monday');
    text(330, 740, 'Wednesday');
    text(60, 700, 'CC 207 Web Systems');
    text(310, 700, 'CIT 210 Databases');
    text(60, 680, '08:00-09:00');
    text(310, 680, '13:00-14:30');
    text(60, 660, 'CB203');
    text(310, 660, 'CB204');
  } else {
    text(40, 700, 'CC 207 Web Systems');
    text(40, 660, 'CIT 210 Databases');
    text(220, 700, 'MWF');
    text(220, 660, 'TTh');
    text(290, 700, '08:00-09:00');
    text(290, 660, '13:00-14:30');
    text(420, 700, 'CB203');
    text(420, 660, 'CB204');
  }
  stream.writeln('ET');
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Count 1 /Kids [3 0 R] >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n${stream}endstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return ascii.encode(pdf.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native PDF text and character geometry preserve each course row',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'wayfinder-pdf-test-',
      );
      try {
        Pdfrx.cacheDirectoryPath = temporary.path;
        // Flutter's test runner does not expose native-assets.yaml to the PDFium
        // loader on macOS. Load the library produced by the package's build hook.
        final hooks = Directory('.dart_tool/hooks_runner');
        if (hooks.existsSync()) {
          for (final entry in hooks.listSync(recursive: true)) {
            if (entry is File && entry.path.endsWith('output.json')) {
              final output =
                  jsonDecode(entry.readAsStringSync()) as Map<String, dynamic>;
              for (final asset in (output['assets'] as List? ?? [])) {
                final encoding = asset['encoding'] as Map?;
                if (encoding?['id'] == 'package:pdfium_dart/libpdfium') {
                  final library = encoding!['file'] as String;
                  final host = Platform.isMacOS
                      ? '/mac-'
                      : Platform.isWindows
                      ? '/win-'
                      : '/linux-';
                  if (library.replaceAll('\\', '/').contains(host)) {
                    Pdfrx.pdfiumModulePath = library;
                  }
                }
              }
            }
          }
        }
        final file = File('${temporary.path}/synthetic-cor.pdf');
        await file.writeAsBytes(tablePdf());
        final result = await const ScheduleImportService().importFile(
          file.path,
        );
        final gridFile = File('${temporary.path}/synthetic-weekly-grid.pdf');
        await gridFile.writeAsBytes(tablePdf(grid: true));
        final grid = await const ScheduleImportService().importFile(
          gridFile.path,
        );
        expect(grid.sessions, hasLength(2), reason: grid.rawText);
        expect(grid.sessions.map((c) => c.weekday), [1, 3]);
        expect(grid.sessions.map((c) => c.roomCodeRaw), ['CB203', 'CB204']);
        expect(result.sessions, hasLength(5), reason: result.rawText);
        final web = result.sessions.where(
          (c) => c.subject.startsWith('CC 207'),
        );
        expect(web.map((c) => c.weekday), [1, 3, 5]);
        expect(web.every((c) => c.roomCodeRaw == 'CB203'), isTrue);
        final database = result.sessions.where(
          (c) => c.subject.startsWith('CIT 210'),
        );
        expect(database.map((c) => c.weekday), [2, 4]);
        expect(database.every((c) => c.roomCodeRaw == 'CB204'), isTrue);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );
}
