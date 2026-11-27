import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/search.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../data/schedule.dart';
import '../data/schedule_import.dart';
import '../data/schedule_documents.dart';
import '../data/browser_schedule.dart';
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
  int? _savedCount;
  final _roomSuggestions = <String, String>{};
  int _reviewVersion = 0;
  static const _sampleRows = [
    'IT 311 | Web Systems and Technologies | M | 10:00-11:30 | C8203 | Prof. Ramon Villaflor',
    'IT 311 | Web Systems and Technologies | WF | 10:00-11:30 | CB203 | Prof. Ramon Villaflor',
    'IT 312 | Information Assurance and Security | MW | 13:00-14:30 | ICT302 | Dr. Celine Abad',
    'IT 313 | Systems Integration and Architecture | TTh | 08:00-09:30 | CB105 | Prof. Luis Cruz',
    'IT 314 | Application Development | TTh | 13:00-14:30 | ICT301 | Prof. Ana Reyes',
  ];

  void _sample(bool cor) {
    setState(() {
      _document = null;
      _error = null;
      _filename = cor ? 'Sample COR' : 'Sample IUIS timetable';
    });
    final text = _sampleRows.join('\n');
    _showResult(
      parseScheduleText(cor ? text.replaceAll('C8203', 'CB203') : text),
    );
  }

  Future<void> _checkRooms(int version) async {
    final places = AppScope.of(context).places;
    final corrections = <String, String>{};
    for (final room in _rows.map((r) => r.roomCodeRaw).toSet()) {
      final code = normalizeRoomCode(room);
      if (!RegExp(r'^[A-Z]+8\d{2,3}$').hasMatch(code)) continue;
      final candidate = code.replaceFirst('8', 'B');
      try {
        if ((await places.search(code)).any((p) => p.place.roomCode == code)) {
          continue;
        }
        if ((await places.search(
              candidate,
            )).where((p) => p.place.roomCode == candidate).length ==
            1) {
          corrections[room] = candidate;
        }
      } catch (_) {
        /* A student can always edit a room manually. */
      }
    }
    if (mounted && version == _reviewVersion && corrections.isNotEmpty) {
      setState(() => _roomSuggestions.addAll(corrections));
    }
  }

  void _correct(int i, String room) {
    final c = _rows[i];
    setState(
      () => _rows[i] = ClassSession(
        id: c.id,
        subject: c.subject,
        weekday: c.weekday,
        start: c.start,
        end: c.end,
        roomCodeRaw: room,
        professor: c.professor,
        remindMinutes: c.remindMinutes,
      ),
    );
  }

  void _chooseAgain() {
    setState(() {
      _reviewVersion++;
      _result = null;
      _document = null;
      _filename = null;
      _error = null;
      _rows.clear();
      _recognized.clear();
      _roomSuggestions.clear();
    });
  }

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
          ? kIsWeb
                ? await ScheduleImportService().importBrowserFile(
                    document.storagePath,
                    await getBrowserFile(document.storagePath),
                  )
                : await ScheduleImportService().importFile(document.path)
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
      _roomSuggestions.clear();
      _result = result;
      _recognized.text = result.rawText;
      _rows
        ..clear()
        ..addAll(result.sessions);
    });
    _checkRooms(++_reviewVersion);
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
        final bytes = file.bytes;
        if (bytes == null && (kIsWeb || file.path == null)) {
          throw const FormatException(
            'The file picker could not open this file. Choose it again.',
          );
        }
        name = file.name;
        final document = bytes != null
            ? await documents.addBytes(bytes, name: file.name)
            : await documents.addFile(file.path!, name: file.name);
        if (!mounted) return;
        setState(() {
          _document = document;
          _filename = name;
          _result = null;
          _rows.clear();
          _recognized.clear();
        });
        result = kIsWeb
            ? await ScheduleImportService().importBrowserFile(
                document.storagePath,
                bytes!,
              )
            : await ScheduleImportService().importFile(document.path);
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
    if (_rows.isEmpty) return;
    if (_rows.any((c) => !_valid(c))) {
      setState(
        () => _error =
            'Complete the subject, day and valid times for each selected class. Tap Edit to correct a row.',
      );
      return;
    }
    final scope = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Only query the public campus directory for room codes; documents stay local.
      final resolved = <String, String?>{};
      final classes = <ClassSession>[];
      for (final c in _rows) {
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
      setState(() => _savedCount = count);
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
  Widget build(BuildContext context) {
    final reviewing = _result != null || _document != null;
    final step = _savedCount != null
        ? 2
        : reviewing
        ? 1
        : 0;
    final next = nextClass(AppScope.of(context).schedule.classes, appClock());
    final days = _rows.map((c) => c.weekday).toSet().length;
    final flagged = _rows
        .where(
          (c) =>
              _roomSuggestions.containsKey(c.roomCodeRaw) ||
              c.roomCodeRaw.isEmpty,
        )
        .length;
    const titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: navy,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: ValueKey(step),
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => context.go(step == 2 ? '/' : '/schedule'),
                      icon: const Icon(Icons.chevron_left),
                      label: Text(step == 2 ? 'Home' : 'My Schedule'),
                    ),
                  ),
                  const Text(
                    'Add my Schedule',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, label) in [
                        'Choose',
                        'Review',
                        'Done',
                      ].indexed)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: i == step ? navy : line,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: i == step
                                      ? navy
                                      : i < step
                                      ? Colors.green.shade100
                                      : blueSoft,
                                  child: i < step
                                      ? const Icon(Icons.check, size: 14)
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: i == step
                                                ? Colors.white
                                                : navy,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (step == 0) ...[
                    const Text(
                      'Upload a screenshot of your IUIS timetable or your Certificate of Registration. You’ll check every class before anything is saved.',
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        key: const Key('choose-schedule'),
                        onTap: _busy ? null : _pick,
                        leading: const Icon(
                          Icons.file_upload_outlined,
                          color: navy,
                        ),
                        title: const Text('Upload a photo, screenshot or PDF'),
                        subtitle: const Text(
                          'PDF, PNG, JPG or WebP · Up to 20 MB',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Or use a sample file', style: titleStyle),
                    for (final cor in [false, true])
                      Card(
                        child: ListTile(
                          onTap: _busy ? null : () => _sample(cor),
                          leading: const Icon(
                            Icons.description_outlined,
                            color: navy,
                          ),
                          title: Text(
                            cor
                                ? 'Certificate of Registration (COR)'
                                : 'IUIS timetable screenshot',
                          ),
                          subtitle: Text(
                            cor
                                ? 'Sample PDF timetable'
                                : 'Sample image timetable',
                          ),
                          trailing: const Text(
                            'Use file',
                            style: TextStyle(color: navy),
                          ),
                        ),
                      ),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) Notice(_error!),
                  if (step == 1) ...[
                    if (_busy && _result == null)
                      const Text('Reading your schedule…', style: titleStyle)
                    else
                      Text(
                        'We found ${_rows.length} ${_rows.length == 1 ? 'class' : 'classes'} on $days ${days == 1 ? 'day' : 'days'}',
                        style: titleStyle,
                      ),
                    if (_filename != null)
                      Text(
                        'From $_filename',
                        style: const TextStyle(color: muted),
                      ),
                    if (flagged > 0)
                      Notice(
                        '$flagged ${flagged == 1 ? 'class needs' : 'classes need'} a room check.',
                      ),
                    for (final w in _result?.warnings ?? <String>[])
                      Notice(w, info: true),
                    for (int d = 1; d <= 7; d++)
                      if (_rows.any((r) => r.weekday == d)) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            weekdays[d - 1].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        for (final i
                            in ([
                              for (var i = 0; i < _rows.length; i++)
                                if (_rows[i].weekday == d) i,
                            ]..sort(
                              (a, b) =>
                                  _rows[a].start.compareTo(_rows[b].start),
                            )))
                          Card(
                            color:
                                _roomSuggestions.containsKey(
                                  _rows[i].roomCodeRaw,
                                )
                                ? goldSoft
                                : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${formatClock(_rows[i].start)}–${formatClock(_rows[i].end)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: navy,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          _rows[i].roomCodeRaw.isEmpty
                                              ? 'Room not specified'
                                              : _rows[i].roomCodeRaw,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(_rows[i].subject, style: titleStyle),
                                  if (_rows[i].professor != null)
                                    Text(_rows[i].professor!),
                                  if (_roomSuggestions[_rows[i].roomCodeRaw]
                                      case final suggestion?)
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _correct(i, suggestion),
                                      child: Text('Use $suggestion'),
                                    ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _edit(i),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit'),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove class from import',
                                        onPressed: _busy
                                            ? null
                                            : () => setState(() {
                                                _rows.removeAt(i);
                                              }),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    if (_document != null)
                      Card(
                        child: ExpansionTile(
                          initiallyExpanded: _rows.isEmpty,
                          title: const Text('Original schedule'),
                          children: [
                            ScheduleDocumentPreview(document: _document!),
                          ],
                        ),
                      ),
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
                            : (value) =>
                                  setState(() => _enableReminders = value),
                      ),
                    ),
                  ],
                  if (step < 2)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.go('/schedule/new'),
                      child: const Text('Add a class manually'),
                    ),
                  if (step == 2)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xffdff3e8),
                              child: Icon(Icons.check, color: Colors.green),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Your schedule is saved',
                              style: titleStyle,
                            ),
                            Text(
                              _savedCount == 0
                                  ? 'These classes are already in your schedule.'
                                  : '$_savedCount class meetings added.',
                            ),
                            if (_enableReminders)
                              Text(
                                AppScope.of(context).notifications.statusText,
                                textAlign: TextAlign.center,
                              ),
                            if (next != null)
                              Card(
                                color: blueSoft,
                                child: ListTile(
                                  title: Text(next.session.subject),
                                  subtitle: Text(
                                    '${weekdays[next.session.weekday - 1]} · ${formatClock(next.session.start)} · ${next.session.roomCodeRaw.isEmpty ? 'Room not specified' : next.session.roomCodeRaw}',
                                  ),
                                  leading: const Icon(Icons.event),
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () => context.go('/'),
                                  child: const Text('Go to Home'),
                                ),
                                OutlinedButton(
                                  onPressed: () => context.go('/schedule'),
                                  child: const Text('View my week'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (step == 1)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : _chooseAgain,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const Key('save-import'),
                          onPressed: _busy || _rows.isEmpty ? null : _save,
                          child: Text(
                            'Confirm ${_rows.length} ${_rows.length == 1 ? 'class' : 'classes'}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
