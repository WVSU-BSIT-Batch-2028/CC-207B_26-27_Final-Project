import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import 'schedule.dart';

/// Extracted document data only; saving the reviewed classes is a separate step.
class ScheduleImportResult {
  const ScheduleImportResult({
    required this.sessions,
    required this.warnings,
    required this.rawText,
  });

  final List<ClassSession> sessions;
  final List<String> warnings;
  final String rawText;
}

typedef ScheduleTextReader = Future<String> Function(String path);

class ScheduleTextPiece {
  const ScheduleTextPiece(this.text, this.bounds);
  final String text;
  final ui.Rect bounds;
}

/// Restores table reading order from positioned PDF characters or OCR lines.
/// Both sources can otherwise return a whole column before the next column.
String assembleScheduleRows(List<ScheduleTextPiece> pieces) {
  final sorted =
      pieces
          .where((p) => p.text.trim().isNotEmpty && !p.bounds.isEmpty)
          .toList()
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  final rows = <List<ScheduleTextPiece>>[];
  for (final piece in sorted) {
    List<ScheduleTextPiece>? row;
    for (final candidate in rows.reversed) {
      final first = candidate.first.bounds;
      final tolerance = math.max(
        2.0,
        math.min(first.height, piece.bounds.height) * .5,
      );
      if ((first.center.dy - piece.bounds.center.dy).abs() <= tolerance) {
        row = candidate;
        break;
      }
      if (piece.bounds.top - first.bottom > 20) break;
    }
    if (row == null) {
      rows.add([piece]);
    } else {
      row.add(piece);
    }
  }
  return rows
      .map((row) {
        row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
        final line = StringBuffer();
        for (var index = 0; index < row.length; index++) {
          if (index > 0) {
            final previous = row[index - 1];
            final gap = row[index].bounds.left - previous.bounds.right;
            final height = math.min(
              row[index].bounds.height,
              previous.bounds.height,
            );
            if (gap > math.max(6, height * 1.5)) {
              line.write(' | ');
            } else if (gap > height * .2) {
              line.write(' ');
            }
          }
          line.write(row[index].text);
        }
        return line.toString();
      })
      .join('\n');
}

/// Reads the selected file locally. No document contents leave the device.
class ScheduleImportService {
  const ScheduleImportService({this.imageTextReader, this.pdfTextReader});

  final ScheduleTextReader? imageTextReader;
  final ScheduleTextReader? pdfTextReader;

  static const maxFileBytes = 20 * 1024 * 1024;
  static const maxPdfPages = 20;

  Future<ScheduleImportResult> importFile(String path) async {
    final file = File(path);
    final size = await file.length();
    if (size == 0) throw const FormatException('This file is empty.');
    if (size > maxFileBytes) {
      throw const FormatException('Choose a schedule smaller than 20 MB.');
    }
    final extension = path.split('.').last.toLowerCase();
    final String text;
    if (extension == 'pdf') {
      text = await (pdfTextReader ?? _readPdf)(path);
    } else if ([
      'jpg',
      'jpeg',
      'png',
      'heic',
      'heif',
      'webp',
    ].contains(extension)) {
      text = await (imageTextReader ?? _readImage)(path);
    } else {
      throw const FormatException('Choose a PDF, JPG or PNG schedule.');
    }
    return parseScheduleText(text);
  }

  Future<String> _readImage(String path) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const FormatException(
        'Photo recognition is available in the Android and iOS app.',
      );
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      // OCR blocks can be whole table columns. Reassemble horizontal rows before
      // parsing, so a room/professor stays beside its subject and meeting time.
      return assembleScheduleRows([
        for (final block in recognized.blocks)
          for (final line in block.lines)
            ScheduleTextPiece(line.text, line.boundingBox),
      ]);
    } finally {
      await recognizer.close();
    }
  }

  Future<String> _readPdf(String path) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openFile(path);
    try {
      if (document.pages.length > maxPdfPages) {
        throw const FormatException(
          'Choose only the schedule pages (up to 20 pages).',
        );
      }
      final text = StringBuffer();
      for (final page in document.pages) {
        final raw = await page.loadText();
        var extracted = raw?.fullText ?? '';
        if (raw != null && raw.charRects.length == raw.fullText.length) {
          // PDF character boxes describe glyph ink, not text advances. Joining
          // individual glyphs by their gaps introduces spaces inside times and
          // course codes. Keep each extracted line intact, then reorder its box.
          final pieces = <ScheduleTextPiece>[];
          var line = StringBuffer();
          ui.Rect? lineBounds;
          void flush() {
            if (lineBounds != null && line.toString().trim().isNotEmpty) {
              pieces.add(ScheduleTextPiece(line.toString(), lineBounds!));
            }
            line = StringBuffer();
            lineBounds = null;
          }

          for (var i = 0; i < raw.fullText.length; i++) {
            final character = raw.fullText[i];
            if (character == '\r' || character == '\n') {
              flush();
              continue;
            }
            line.write(character);
            final box = raw.charRects[i];
            final bounds = ui.Rect.fromLTRB(
              box.left,
              -box.top,
              box.right,
              -box.bottom,
            );
            if (!bounds.isEmpty) {
              lineBounds = lineBounds?.expandToInclude(bounds) ?? bounds;
            }
          }
          flush();
          final arranged = assembleScheduleRows(pieces);
          if (arranged.trim().isNotEmpty) extracted = arranged;
        }
        // A scan has no text layer. A badly ordered text layer may not expose a
        // complete row either; raster OCR gives the parser another local input.
        if (parseScheduleText(extracted).sessions.isEmpty &&
            (Platform.isAndroid || Platform.isIOS)) {
          final temporary = await Directory.systemTemp.createTemp(
            'wayfinder-schedule-',
          );
          try {
            final scale = math.min(
              3.0,
              2400 / math.max(page.width, page.height),
            );
            final raster = await page.render(
              fullWidth: page.width * scale,
              fullHeight: page.height * scale,
            );
            if (raster != null) {
              try {
                final image = await raster.createImage();
                try {
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  if (png != null) {
                    final file = File('${temporary.path}/page.png');
                    await file.writeAsBytes(
                      png.buffer.asUint8List(
                        png.offsetInBytes,
                        png.lengthInBytes,
                      ),
                    );
                    final ocr = await _readImage(file.path);
                    if (ocr.trim().isNotEmpty) extracted = ocr;
                  }
                } finally {
                  image.dispose();
                }
              } finally {
                raster.dispose();
              }
            }
          } finally {
            await temporary.delete(recursive: true);
          }
        }
        text.writeln(extracted);
      }
      return text.toString();
    } finally {
      await document.dispose();
    }
  }
}

final _course = RegExp(
  r'^\s*(?:\d{1,3}[.)]?\s+)?([A-Za-z]{2,8}\s*[- ]?\s*\d{1,3}[A-Za-z]?)(?!\d)\b',
);
final _timeRange = RegExp(
  r'(?<![\d:])(\d{3,4}|\d{1,2}(?::\d{2}|\.\d{2})?)\s*(a\.?\s*m\.?|p\.?\s*m\.?)?\s*(?:[-–—]|\bto\b)\s*(\d{3,4}|\d{1,2}(?::\d{2}|\.\d{2})?)\s*(a\.?\s*m\.?|p\.?\s*m\.?)?(?!\d)',
  caseSensitive: false,
);
const _dayToken =
    r'(?:MONDAY|MON|TUESDAY|TUES|TUE|WEDNESDAY|WED|THURSDAY|THURS|THUR|THU|FRIDAY|FRI|SATURDAY|SAT|SUNDAY|SUN|MTWTHF|MTWRF|MTWF|MTW|TTH|TH|MWF|MW|WF|MF|TR|[MTWRFSU])';
final _days = RegExp(
  '(?<![A-Za-z])$_dayToken(?:[ /,&]+$_dayToken)*(?![A-Za-z])',
  caseSensitive: false,
);
final _professor = RegExp(
  r'\b(?:professor|prof\.?|instructor|faculty|teacher)\s*[:.]?\s*(.+?)(?=\s*[|;]|$)',
  caseSensitive: false,
);
final _roomLabel = RegExp(
  r'\b(?:classroom|room|rm|venue)\.?\s*[:#-]?\s*(.+?)(?=\s*[|;]|\s+(?:professor|prof\.?|instructor|faculty|teacher)\b|$)',
  caseSensitive: false,
);
final _roomCode = RegExp(
  r'\b(?:[A-Za-z]{1,8}[ -]*\d{1,4}[A-Za-z]?|ONLINE|GYM|TBA|ARRANGED)\b',
  caseSensitive: false,
);

/// Parses common row-based IUIS/COR exports. Ambiguous or incomplete meetings
/// remain warnings for review rather than guessed class times.
ScheduleImportResult parseScheduleText(String text) {
  final warnings = <String>[];
  final sessions = <ClassSession>[];
  final seen = <String>{};
  final chunks = <String>[];
  var current = '';
  for (var line in text.replaceAll('\r', '\n').split('\n')) {
    line = line
        .replaceAll('\t', ' | ')
        .replaceAll(RegExp(r'\s{2,}'), ' | ')
        .trim();
    if (line.isEmpty) continue;
    if (RegExp(
      r'^(?:academic year|school year|semester|total(?: units)?|page\s+\d|printed|date generated|student\s+(?:name|number|id)|AY|SY)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      continue;
    }
    final match = _course.firstMatch(line);
    final firstLineTime = _timeRange.firstMatch(line);
    final isRoom =
        match != null &&
        RegExp(
          r'^(?:CB|CL|IT|ICT|EB|SB|AB|LB|NB|MB|LAB|COMLAB|ROOM|RM|BLDG|LIB)(?=[ -]*\d)',
          caseSensitive: false,
        ).hasMatch(match.group(1)!) &&
        !_timeRange.hasMatch(line);
    // "MWF 08:00-09:00" starts with letters and digits too, but its
    // apparent course number is already part of the meeting time.
    final isMeetingContinuation =
        match != null &&
        firstLineTime != null &&
        firstLineTime.start < match.end;
    if (match != null && !isRoom && !isMeetingContinuation) {
      if (current.isNotEmpty) chunks.add(current);
      current = line;
    } else if (current.isNotEmpty) {
      current += ' | $line';
    }
  }
  if (current.isNotEmpty) chunks.add(current);

  for (final chunk in chunks) {
    final course = _course.firstMatch(chunk)!;
    final code = course.group(1)!.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    final ranges = _timeRange
        .allMatches(chunk)
        .where((range) => range.start >= course.end)
        .toList();
    if (ranges.isEmpty) {
      warnings.add(
        '$code: no readable meeting time. Add this class manually if needed.',
      );
      continue;
    }
    final firstTime = ranges.first;
    final before = chunk.substring(course.end, firstTime.start);
    final firstDay = _days.firstMatch(before);
    var title = before
        .substring(0, firstDay?.start ?? before.length)
        .replaceAll(
          RegExp(
            r'\b(?:units?|credits?|lec|lab)\s*[:.]?\s*\d*(?:\.\d+)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'(?:[|;,\s]+\d+(?:\.\d+)?)+[|;,\s]*$'), '')
        .replaceAll(RegExp(r'[|;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    title = title.replaceAll(RegExp(r'^[\s:,-]+|[\s:,-]+$'), '');
    final subject = title.isEmpty ? code : '$code $title';
    final globalProfessor = _professor.firstMatch(chunk)?.group(1)?.trim();
    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      final previousEnd = index == 0 ? course.end : ranges[index - 1].end;
      final leading = chunk.substring(previousEnd, range.start);
      final leadingDay = _days.allMatches(leading).lastOrNull;
      final nextStart = index + 1 < ranges.length
          ? ranges[index + 1].start
          : chunk.length;
      var trailing = chunk.substring(range.end, nextStart);
      // A day belongs to this meeting only when adjacent to its time column.
      // This distinguishes "MWF 08-09 CB203 | F 10-12 LAB1" from
      // "08-09 MWF CB203 | 10-12 F LAB1" without reusing the previous days.
      final trailingDay = _days.firstMatch(trailing);
      final separators = RegExp(r'^[\s|;,:/-]*$');
      final hasLeadingDay =
          leadingDay != null &&
          separators.hasMatch(leading.substring(leadingDay.end));
      final hasTrailingDay =
          trailingDay != null &&
          separators.hasMatch(trailing.substring(0, trailingDay.start));
      final dayAfterTime = !hasLeadingDay && hasTrailingDay;
      final dayMatch = hasLeadingDay
          ? leadingDay
          : dayAfterTime
          ? trailingDay
          : null;
      final weekdays = dayMatch == null
          ? <int>[]
          : _parseDays(dayMatch.group(0)!);
      final times = _parseRange(range);
      if (weekdays.isEmpty || times == null) {
        warnings.add(
          '$code: a meeting has an unreadable day or time. Check the original document.',
        );
        continue;
      }
      if (dayAfterTime) {
        trailing = trailing.replaceRange(
          trailingDay.start,
          trailingDay.end,
          ' ',
        );
      } else if (index + 1 < ranges.length &&
          trailingDay != null &&
          separators.hasMatch(trailing.substring(trailingDay.end))) {
        // In day-before-time rows the final weekday belongs to the next range.
        trailing = trailing.substring(0, trailingDay.start);
      }
      final explicitRoom = _roomLabel.firstMatch(trailing);
      final roomMatch = _roomCode.firstMatch(trailing);
      var room =
          explicitRoom?.group(1)?.trim() ?? roomMatch?.group(0)?.trim() ?? '';
      if (room.isEmpty) {
        final numberRoom = RegExp(r'^[\s|;,]*(\d{2,4})\b').firstMatch(trailing);
        room = numberRoom?.group(1) ?? '';
      }
      String? professor =
          _professor.firstMatch(trailing)?.group(1)?.trim() ?? globalProfessor;
      if (professor == null && roomMatch != null) {
        final remaining = trailing
            .substring(roomMatch.end)
            .replaceAll(RegExp(r'^[\s|;,:-]+|[\s|;,:-]+$'), '')
            .trim();
        if (remaining.isNotEmpty &&
            !RegExp(
              r'\d|\b(?:units?|TBA|ARR)\b',
              caseSensitive: false,
            ).hasMatch(remaining)) {
          professor = remaining.replaceAll(RegExp(r'\s*[|;]\s*'), ' ').trim();
        }
      }
      if (professor != null &&
          RegExp(
            r'^(?:TBA|ARR|ARRANGED|TO BE ANNOUNCED)$',
            caseSensitive: false,
          ).hasMatch(professor)) {
        professor = null;
      }
      if (room.isEmpty ||
          RegExp(r'^(?:TBA|ARRANGED)$', caseSensitive: false).hasMatch(room)) {
        warnings.add('$code: confirm the classroom before saving.');
      }
      if (professor == null || professor.isEmpty) {
        warnings.add('$code: professor was not detected.');
      }
      for (final day in weekdays) {
        final signature =
            '$subject|$day|${times.$1}|${times.$2}|${room.toUpperCase().replaceAll(' ', '')}';
        if (!seen.add(signature)) continue;
        sessions.add(
          ClassSession(
            id: 'import-${DateTime.now().microsecondsSinceEpoch}-${sessions.length}',
            subject: subject,
            weekday: day,
            start: times.$1,
            end: times.$2,
            roomCodeRaw: room,
            professor: professor == null || professor.isEmpty
                ? null
                : professor,
            remindMinutes: 15,
          ),
        );
      }
    }
  }
  if (sessions.isEmpty) {
    warnings.add(
      'No complete class meetings were detected. Try a clearer schedule or add the classes manually.',
    );
  }
  return ScheduleImportResult(
    sessions: sessions,
    warnings: warnings.toSet().toList(),
    rawText: text,
  );
}

List<int> _parseDays(String value) {
  final normalized = value.toUpperCase();
  final result = <int>{};
  final token = RegExp(_dayToken, caseSensitive: false);
  for (final match in token.allMatches(normalized)) {
    final day = match.group(0)!;
    if (day == 'MTWTHF' || day == 'MTWRF') {
      result.addAll([1, 2, 3, 4, 5]);
    } else if (day == 'MTWF') {
      result.addAll([1, 2, 3, 5]);
    } else if (day == 'MTW') {
      result.addAll([1, 2, 3]);
    } else if (day == 'MWF') {
      result.addAll([1, 3, 5]);
    } else if (day == 'MW') {
      result.addAll([1, 3]);
    } else if (day == 'MF') {
      result.addAll([1, 5]);
    } else if (day == 'WF') {
      result.addAll([3, 5]);
    } else if (day == 'TTH' || day == 'TR') {
      result.addAll([2, 4]);
    } else if (day.startsWith('MON') || day == 'M') {
      result.add(1);
    } else if (day.startsWith('TUE') || day == 'T') {
      result.add(2);
    } else if (day.startsWith('WED') || day == 'W') {
      result.add(3);
    } else if (day.startsWith('TH') || day == 'R') {
      result.add(4);
    } else if (day.startsWith('FRI') || day == 'F') {
      result.add(5);
    } else if (day.startsWith('SAT') || day == 'S') {
      result.add(6);
    } else if (day.startsWith('SUN') || day == 'U') {
      result.add(7);
    }
  }
  return result.toList()..sort();
}

(String, String)? _parseRange(RegExpMatch match) {
  String? meridiem(String? input) =>
      input?.toLowerCase().replaceAll(RegExp(r'[^apm]'), '');
  final startMeridiem = meridiem(match.group(2));
  final endMeridiem = meridiem(match.group(4));
  int? minutes(String input, String? suffix) {
    final parts = input.replaceAll('.', ':').split(':');
    int hour;
    int minute;
    if (parts.length == 2) {
      hour = int.parse(parts[0]);
      minute = int.parse(parts[1]);
    } else if (input.length >= 3) {
      final compact = int.parse(input);
      hour = compact ~/ 100;
      minute = compact % 100;
    } else {
      hour = int.parse(input);
      minute = 0;
    }
    if (minute > 59 ||
        hour > 23 ||
        (suffix != null && (hour < 1 || hour > 12))) {
      return null;
    }
    if (suffix != null) hour = hour % 12 + (suffix == 'pm' ? 12 : 0);
    return hour * 60 + minute;
  }

  var start = minutes(match.group(1)!, startMeridiem ?? endMeridiem);
  var end = minutes(match.group(3)!, endMeridiem ?? startMeridiem);
  if (start == null || end == null) return null;
  // With the meridiem printed once, 11:00–1:00 PM crosses noon, not midnight.
  if (start >= end &&
      startMeridiem == null &&
      endMeridiem == 'pm' &&
      start >= 12 * 60) {
    start -= 12 * 60;
  }
  if (start >= end &&
      endMeridiem == null &&
      startMeridiem == 'am' &&
      end < 12 * 60) {
    end += 12 * 60;
  }
  if (end <= start || end - start > 8 * 60) return null;
  String clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  return (clock(start), clock(end));
}
