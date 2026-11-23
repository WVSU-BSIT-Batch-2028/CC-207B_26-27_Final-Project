import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'schedule.dart';

/// Device-local equivalent of schedule_uploads; no anonymous cloud upload.
class ScheduleDocument {
  const ScheduleDocument({
    required this.id,
    required this.storagePath,
    required this.uploadedAt,
    required this.name,
    required this.path,
    this.text = '',
  });
  final String id, storagePath, name, path, text;
  final DateTime uploadedAt;
  bool get isPdf => storagePath.toLowerCase().endsWith('.pdf');
  Map<String, dynamic> toJson() => {
    'id': id,
    'storage_path': storagePath,
    'uploaded_at': uploadedAt.toUtc().toIso8601String(),
    'name': name,
    'recognized_text': text,
  };
  ScheduleDocument withText(String value) => ScheduleDocument(
    id: id,
    storagePath: storagePath,
    uploadedAt: uploadedAt,
    name: name,
    path: path,
    text: value,
  );
}

class ScheduleDocumentStore extends ChangeNotifier {
  ScheduleDocumentStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  static const _key = 'wf.schedule.uploads.v1';
  final Future<Directory> Function() _directory;
  List<ScheduleDocument> _uploads = [];
  Future<void>? _loading;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  String? error;
  List<ScheduleDocument> get uploads => List.unmodifiable(_uploads);
  ScheduleDocument? byId(String id) =>
      _uploads.where((d) => d.id == id).firstOrNull;

  Future<Directory> _folder() async =>
      Directory('${(await _directory()).path}/schedule_uploads');
  Future<void> load() => _loading ??= _load().catchError((Object cause) {
    _loading = null;
    error =
        'Saved schedule files could not be loaded. Try again or choose the original file.';
    _changed();
    throw cause;
  });
  Future<void> loadForDisplay() async {
    try {
      await load();
    } catch (_) {
      /* The screen displays error and offers retry. */
    }
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    error = null;
    if (raw == null) {
      _changed();
      return;
    } // No platform file API needed for a new schedule.
    final folder = await _folder();
    _uploads = (jsonDecode(raw) as List).map((row) {
      final j = row as Map<String, dynamic>;
      final relative = j['storage_path'] as String;
      // Metadata only ever resolves inside the app's private upload folder.
      if (relative.contains('/') ||
          relative.contains('\\') ||
          relative.contains('..')) {
        throw const FormatException('Invalid saved schedule path.');
      }
      return ScheduleDocument(
        id: j['id'] as String,
        storagePath: relative,
        uploadedAt: DateTime.parse(j['uploaded_at'] as String),
        name: j['name'] as String,
        path: '${folder.path}/$relative',
        text: j['recognized_text'] as String? ?? '',
      );
    }).toList();
    _changed();
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> _persist(List<ScheduleDocument> documents) async {
    final p = await SharedPreferences.getInstance();
    final previous = p.getString(_key);
    try {
      if (!await p.setString(
        _key,
        jsonEncode(documents.map((d) => d.toJson()).toList()),
      )) {
        throw StateError('The document could not be saved on this phone.');
      }
    } catch (_) {
      try {
        if (previous == null) {
          await p.remove(_key);
        } else {
          await p.setString(_key, previous);
        }
      } catch (_) {
        /* Keep the original persistence error. */
      }
      rethrow;
    }
    _uploads = documents;
    _changed();
  }

  Future<ScheduleDocument> addFile(String path, {required String name}) =>
      _serialize(() async {
        await load();
        final source = File(path);
        final size = await source.length();
        if (size == 0 || size > 20 * 1024 * 1024) {
          throw const FormatException(
            'Choose a nonempty schedule smaller than 20 MB.',
          );
        }
        final extension = name.split('.').last.toLowerCase();
        if (!['pdf', 'png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
          throw const FormatException(
            'Choose a PDF, PNG, JPG or WebP schedule.',
          );
        }
        final folder = await _folder();
        await folder.create(recursive: true);
        final id = newScheduleId();
        final relative = '$id.$extension';
        final destination = File('${folder.path}/$relative');

        final document = ScheduleDocument(
          id: id,
          storagePath: relative,
          uploadedAt: DateTime.now().toUtc(),
          name: name,
          path: destination.path,
        );
        try {
          await source.copy(destination.path);
          await _persist([document, ..._uploads]);
        } catch (_) {
          if (await destination.exists()) await destination.delete();
          rethrow;
        }
        return document;
      });
  Future<void> updateText(String id, String text) => _serialize(() async {
    await load();
    await _persist([
      for (final d in _uploads) d.id == id ? d.withText(text) : d,
    ]);
  });
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
