import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/search.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../data/schedule.dart';
import '../data/schedule_import.dart';
import '../data/schedule_documents.dart';
import '../widgets/schedule_document_preview.dart';
import '../widgets/common.dart';

class ImportScheduleScreen extends StatefulWidget {
  const ImportScheduleScreen({super.key, this.uploadId});
  final String? uploadId;

  /// Supplies extracted rows without opening a native picker in widget tests.
  static Future<ScheduleImportResult?> Function()? debugImport;

  @override
  State<ImportScheduleScreen> createState() => _ImportScheduleScreenState();
}

class _ImportScheduleScreenState extends State<ImportScheduleScreen> {
  ScheduleImportResult? _result;
  ScheduleDocument? _document;
  final _recognized = TextEditingController();
  bool _opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opening && widget.uploadId != null) {
      _opening = true;
      _openSaved(widget.uploadId!);
    }
  }

  Future<void> _openSaved(String id) async {
    final documents = AppScope.of(context).documents;
    setState(() => _busy = true);
    try {
      await documents.load();
      final document = documents.byId(id);
      if (document == null) {
        throw const FormatException(
          'Saved document not found. Choose the file again.',
        );
      }
      if (!mounted) return;
      setState(() {
        _document = document;
        _filename = document.name;
      });
      final result = document.text.trim().isEmpty
          ? await ScheduleImportService().importFile(document.path)
          : parseScheduleText(document.text);
      if (mounted) _showResult(result);
      try {
        await documents.updateText(id, result.rawText);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Classes were read, but the recognized text could not be cached. You can still review and save the classes.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The saved file could not be read. You can still enter its class details below or choose it again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(ScheduleImportResult result) {
    setState(() {
      _result = result;
      _recognized.text = result.rawText;
      _rows
        ..clear()
        ..addAll(result.sessions);
      _selected
        ..clear()
        ..addAll(List.generate(_rows.length, (i) => i));
    });
  }

  Future<void> _readText() async {
    setState(() => _error = null);
    final documents = AppScope.of(context).documents;
    final result = parseScheduleText(_recognized.text);
    _showResult(result);
    if (_document != null) {
      try {
        await documents.updateText(_document!.id, result.rawText);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'The corrected text could not be saved. Try again.',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _recognized.dispose();
    super.dispose();
  }

  final _rows = <ClassSession>[];
  final _selected = <int>{};
  bool _busy = false;
  bool _enableReminders = true;
  String? _error;
  String? _filename;

  Future<void> _pick() async {
    final documents = AppScope.of(context).documents;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ScheduleImportResult? result;
      String? name;
      if (ImportScheduleScreen.debugImport != null) {
        result = await ImportScheduleScreen.debugImport!();
        name = 'Test schedule';
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
          allowMultiple: false,
          withData: true,
        );
        if (picked == null) return;
        final file = picked.files.single;
        if (file.size > 20 * 1024 * 1024) {
          throw const FormatException('Choose a schedule smaller than 20 MB.');
        }
        if (file.path == null && file.bytes == null) {
          throw const FormatException(
            'Open this import on an Android or iOS phone.',
          );
        }
        name = file.name;
        final document = file.bytes != null
            ? await documents.addBytes(file.bytes!, name: file.name)
            : await documents.addFile(file.path!, name: file.name);
        if (!mounted) return;
        setState(() {
          _document = document;
          _filename = name;
          _result = null;
          _rows.clear();
          _selected.clear();
          _recognized.clear();
        });
        result = await ScheduleImportService().importFile(document.path);
        if (mounted) _showResult(result);
        try {
          await documents.updateText(document.id, result.rawText);
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Classes were read, but the recognized text could not be cached. You can still review and save the classes.',
            );
          }
        }
      }
      if (!mounted || result == null) return;
      setState(() => _filename = name);
      _showResult(result);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This schedule couldn’t be read. Try a clear screenshot or an unlocked PDF, or add classes manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _valid(ClassSession c) {
    try {
      c.validate();
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> _save() async {
    final chosen = _selected.toList()..sort();
    if (chosen.isEmpty) return;
    if (chosen.any((i) => !_valid(_rows[i]))) {
      setState(
        () => _error =
            'Complete the subject, day and valid times for each selected class. Tap Edit to correct a row.',
      );
      return;
    }
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Only query the public campus directory for room codes; documents stay local.
      final resolved = <String, String?>{};
      final classes = <ClassSession>[];
      for (final i in chosen) {
        final c = _rows[i];
        final room = c.roomCodeRaw.trim();
        if (!resolved.containsKey(room)) {
          String? placeId;
          if (looksLikeRoomCode(room)) {
            try {
              final hits = (await scope.places.search(room))
                  .where((p) => p.place.roomCode == normalizeRoomCode(room))
                  .toList();
              if (hits.length == 1) placeId = hits.single.place.id;
            } catch (_) {
              /* An unmatched room remains available for manual lookup. */
            }
          }
          resolved[room] = placeId;
        }
        classes.add(
          ClassSession(
            id: newScheduleId(),
            uploadId: _document?.id,
            subject: c.subject.trim(),
            weekday: c.weekday,
            start: c.start,
            end: c.end,
            roomCodeRaw: room,
            roomPlaceId: resolved[room],
            professor: c.professor?.trim().isEmpty == true
                ? null
                : c.professor?.trim(),
            remindMinutes: _enableReminders ? 15 : null,
          ),
        );
      }
      final count = await scope.schedule.importClasses(classes);
      if (_enableReminders &&
          scope.notifications.supported &&
          !scope.notifications.enabled) {
        await scope.notifications.enable();
      }
      if (!mounted) return;
      context.go('/schedule');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'These classes are already in your schedule.'
                : 'Added $count class meetings. Check class reminder status below.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your schedule couldn’t be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(int i) async {
    final edited = await showDialog<ClassSession>(
      context: context,
      builder: (_) => _ReviewClassDialog(session: _rows[i]),
    );
    if (edited != null && mounted) setState(() => _rows[i] = edited);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextButton.icon(
        onPressed: _busy ? null : () => context.go('/schedule'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('My Schedule'),
      ),
      const Text(
        'Add my Schedule',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Upload the schedule you generated in IUIS or your Certificate of Registration (COR). We’ll fill in the classes for you.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.upload_file_outlined, size: 36, color: wayBlue),
              const SizedBox(height: 8),
              const Text(
                'PDF, screenshot or photo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const Text(
                'PDF, PNG or JPG · Up to 20 MB. Use a clear image with the full class table visible.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('choose-schedule'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(
                  _result == null
                      ? 'Choose schedule file'
                      : 'Choose another file',
                ),
              ),
              if (_filename != null)
                Text(_filename!, overflow: TextOverflow.ellipsis),
              if (_document != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Saved on this phone',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ScheduleDocumentPreview(document: _document!),
              ],
            ],
          ),
        ),
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 8),
              Text('Processing schedule…'),
            ],
          ),
        ),
      const Text(
        'Text recognition happens on your phone. Your document is not uploaded to a server. Class times use Asia/Manila.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      if (_error != null) Notice(_error!),
      if (_result != null || _document != null)
        Card(
          child: ExpansionTile(
            key: const Key('recognized-text-panel'),
            title: const Text('Review recognized text'),
            initiallyExpanded: _rows.isEmpty,
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Text(
                _recognized.text.trim().isEmpty
                    ? 'No readable text was found. You can type or paste the class details from your schedule here.'
                    : 'If classes are missing, correct the text below and read it again. Each class needs a subject, day and time.',
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('recognized-text'),
                controller: _recognized,
                minLines: 5,
                maxLines: 12,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Schedule text',
                  alignLabelWithHint: true,
                  hintText:
                      'Subject | Day | Time | Room | Professor\nCC 207 | MWF | 08:00-09:00 | CB203 | Prof. Cruz',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('read-schedule-text'),
                onPressed: _busy ? null : _readText,
                icon: const Icon(Icons.refresh),
                label: const Text('Read these details'),
              ),
            ],
          ),
        ),
      if (_result != null) ...[
        const SizedBox(height: 16),
        Text(
          'Review ${_rows.length} detected class meetings',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Check the days, times, rooms and professors before saving. Uncheck rows you don’t need. Each meeting gets a 15-minute reminder.',
        ),
        for (final warning in _result!.warnings) Notice(warning, info: true),

        for (var i = 0; i < _rows.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _selected.contains(i),
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                            () => value == true
                                ? _selected.add(i)
                                : _selected.remove(i),
                          ),
                    title: Text(_rows[i].subject),
                    subtitle: Text(
                      '${weekdays[_rows[i].weekday - 1]} · ${formatClock(_rows[i].start)}–${formatClock(_rows[i].end)}\n'
                      'Room: ${_rows[i].roomCodeRaw.isEmpty ? 'Needs review' : _rows[i].roomCodeRaw}\n'
                      'Professor: ${_rows[i].professor ?? 'Not detected'}',
                    ),
                    isThreeLine: true,
                  ),
                  if (!_valid(_rows[i]))
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Complete this class before saving.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: TextButton.icon(
                      onPressed: _busy ? null : () => _edit(i),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('save-import'),
          onPressed: _busy || _selected.isEmpty ? null : _save,
          child: Text('Save ${_selected.length} class meetings'),
        ),
      ],
      const SizedBox(height: 8),
      Material(
        color: Colors.transparent,
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable class reminders'),
          subtitle: const Text(
            'Allow notifications when prompted to get a reminder 15 minutes before each class.',
          ),
          value: _enableReminders,
          onChanged: _busy
              ? null
              : (value) => setState(() => _enableReminders = value),
        ),
      ),
      OutlinedButton(
        onPressed: _busy ? null : () => context.go('/schedule/new'),
        child: const Text('Add a class manually'),
      ),
    ],
  );
}

class _ReviewClassDialog extends StatefulWidget {
  const _ReviewClassDialog({required this.session});
  final ClassSession session;
  @override
  State<_ReviewClassDialog> createState() => _ReviewClassDialogState();
}

class _ReviewClassDialogState extends State<_ReviewClassDialog> {
  final _form = GlobalKey<FormState>();
  late final _subject = TextEditingController(text: widget.session.subject);
  late final _room = TextEditingController(text: widget.session.roomCodeRaw);
  late final _prof = TextEditingController(text: widget.session.professor);
  late final _start = TextEditingController(text: widget.session.start);
  late final _end = TextEditingController(text: widget.session.end);
  late int _day = widget.session.weekday;

  @override
  void dispose() {
    for (final c in [_subject, _room, _prof, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _time(String? s) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s ?? '')
      ? null
      : 'Use HH:mm (24h)';
  Widget _field(
    String label,
    TextEditingController c, {
    bool required = false,
    bool time = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      validator: (v) => time
          ? _time(v)
          : required && (v ?? '').trim().isEmpty
          ? 'Required'
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review class'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Subject', _subject, required: true),
              DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(value: d, child: Text(weekdays[d - 1])),
                ],
                onChanged: (d) => _day = d ?? _day,
              ),
              _field('Starts (24h)', _start, time: true),
              _field('Ends (24h)', _end, time: true),
              _field('Room (optional)', _room),
              _field('Professor', _prof),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          if (toMinutes(_end.text) <= toMinutes(_start.text)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('End time must be after start time.'),
              ),
            );
            return;
          }
          Navigator.pop(
            context,
            ClassSession(
              id: widget.session.id,
              subject: _subject.text.trim(),
              weekday: _day,
              start: _start.text,
              end: _end.text,
              roomCodeRaw: _room.text.trim(),
              professor: _prof.text.trim().isEmpty ? null : _prof.text.trim(),
              remindMinutes: 15,
            ),
          );
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
