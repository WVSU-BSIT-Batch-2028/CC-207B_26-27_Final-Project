import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/search.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../data/schedule.dart';
import '../widgets/common.dart';
import '../widgets/schedule_document_preview.dart';
import 'home_screen.dart' show Unconfirmed;

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).schedule;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final classes = store.classes;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Home'),
            ),
            const Text(
              'My Schedule',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const Notice(
              'Private: your timetable and classes are saved on this device only. Times use Asia/Manila.',
              info: true,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import your IUIS schedule or COR',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload a PDF, photo or screenshot. Review the detected classes, then save them with reminders.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/schedule/import'),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Add my Schedule'),
                    ),
                  ],
                ),
              ),
            ),
            if (store.imageBase64 != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Previously uploaded timetable'),
                      Image.memory(
                        base64Decode(store.imageBase64!),
                        height: 180,
                        fit: BoxFit.contain,
                        semanticLabel: 'Your uploaded timetable',
                      ),
                      TextButton(
                        onPressed: () => store.setImage(null),
                        child: const Text('Remove image'),
                      ),
                    ],
                  ),
                ),
              ),
            ListenableBuilder(listenable: AppScope.of(context).documents, builder: (context, _) {
            final uploads = AppScope.of(context).documents.uploads;
            final documents = AppScope.of(context).documents;
            if (documents.error != null) {
              return Column(children: [
              Notice(documents.error!),
              OutlinedButton(onPressed: documents.loadForDisplay, child: const Text('Retry loading saved files')),
            ]);
            }
            if (uploads.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SAVED SCHEDULE FILES', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final document in uploads) Card(child: Padding(padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(document.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ScheduleDocumentPreview(document: document),
                  OutlinedButton(onPressed: () => context.go('/schedule/import?upload=${document.id}'),
                    child: const Text('Review classes from this file')),
                ]),
              )),
            ]);
          }),
          ListenableBuilder(
              listenable: AppScope.of(context).notifications,
              builder: (context, _) {
                final notifications = AppScope.of(context).notifications;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class reminders',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notifications.statusText,
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                        if (notifications.supported) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: notifications.enable,
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                            label: Text(
                              notifications.enabled
                                  ? 'Check reminder permissions'
                                  : 'Enable class reminders',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'WEEKLY CLASSES',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/schedule/new'),
                  child: const Text('Add class'),
                ),
              ],
            ),
            if (classes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No classes yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            for (var d = 1; d <= 7; d++)
              if (classes.any((c) => c.weekday == d)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    weekdays[d - 1],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ),
                for (final c
                    in classes.where((c) => c.weekday == d).toList()
                      ..sort((a, b) => a.start.compareTo(b.start)))
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.go('/schedule/${c.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${formatClock(c.start)}–${formatClock(c.end)}${c.professor != null ? ' · ${c.professor}' : ''}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (c.roomPlaceId == null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Unconfirmed(
                                        'Room location unconfirmed',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 100), child: Text(
                              c.roomCodeRaw.isEmpty ? 'Room not specified' : c.roomCodeRaw,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
          ],
        );
      },
    );
  }
}

class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.classId});
  final String? classId;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _subject = TextEditingController(), _start = TextEditingController(text: '08:00'), _end = TextEditingController(text: '09:30');
  final _room = TextEditingController(), _prof = TextEditingController();
  int _weekday = 1;
  int? _remind = 15;
  String? _error;
  bool _saving = false, _init = false;
  ClassSession? _existing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final c = widget.classId == null ? null : AppScope.of(context).schedule.byId(widget.classId!);
    _existing = c;
    if (c != null) {
      _subject.text = c.subject;
      _start.text = c.start;
      _end.text = c.end;
      _room.text = c.roomCodeRaw;
      _prof.text = c.professor ?? '';
      _weekday = c.weekday;
      _remind = c.remindMinutes;
    }
  }

  @override
  void dispose() {
    for (final c in [_subject, _start, _end, _room, _prof]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  Future<void> _save() async {
    final scope = AppScope.of(context);
    setState(() => _error = null);
    if (_subject.text.trim().isEmpty) return setState(() => _error = 'Enter the subject.');
    if (!_hhmm.hasMatch(_start.text) || !_hhmm.hasMatch(_end.text)) return setState(() => _error = 'Use 24-hour times like 08:00 or 13:30.');
    if (toMinutes(_end.text) <= toMinutes(_start.text)) return setState(() => _error = 'End time must be after the start time.');
    setState(() => _saving = true);
    final raw = _room.text.trim();
    String? placeId;
    if (looksLikeRoomCode(raw)) {
      try {
        final hits = (await scope.places.search(raw)).where((v) => v.place.roomCode == normalizeRoomCode(raw)).toList();
        if (hits.length == 1) placeId = hits.first.place.id;
      } catch (_) {/* lookup failed: keep as unconfirmed */}
    }
    await scope.schedule.save(ClassSession(
      id: _existing?.id ?? newScheduleId(),
      uploadId: _existing?.uploadId,
      subject: _subject.text.trim(),
      weekday: _weekday,
      start: _start.text,
      end: _end.text,
      roomCodeRaw: raw,
      roomPlaceId: placeId,
      professor: _prof.text.trim().isEmpty ? null : _prof.text.trim(),
      remindMinutes: _remind,
    ));
    if (mounted) context.go('/schedule');
  }

  InputDecoration _dec(String label, [String? hint]) => InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) {
    if (widget.classId != null && _existing == null) {
      return ListView(padding: const EdgeInsets.all(16), children: const [Text('Class not found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextButton.icon(onPressed: () => context.go('/schedule'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('My Schedule')),
      Text(_existing == null ? 'Add class' : 'Edit class', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      TextField(key: const Key('subject'), controller: _subject, decoration: _dec('Subject', 'e.g. CIT 210 Web Systems')),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(
        key: const Key('day'),
        initialValue: _weekday,
        decoration: _dec('Day'),
        items: [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text(weekdays[i - 1]))],
        onChanged: (v) => setState(() => _weekday = v ?? 1),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(key: const Key('start'), controller: _start, decoration: _dec('Starts (24h)', '08:00'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(key: const Key('end'), controller: _end, decoration: _dec('Ends (24h)', '09:30'))),
      ]),
      const SizedBox(height: 10),
      TextField(key: const Key('room'), controller: _room, decoration: _dec('Room code', 'As written on your timetable, e.g. CB 203')),
      const SizedBox(height: 10),
      TextField(key: const Key('prof'), controller: _prof, decoration: _dec('Professor', 'Optional')),
      const SizedBox(height: 10),
      DropdownButtonFormField<int?>(
        key: const Key('remind'),
        initialValue: _remind,
        decoration: _dec('Reminder'),
        items: const [
          DropdownMenuItem(value: null, child: Text('No reminder')),
          DropdownMenuItem(value: 5, child: Text('5 minutes before')),
          DropdownMenuItem(value: 10, child: Text('10 minutes before')),
          DropdownMenuItem(value: 15, child: Text('15 minutes before')),
          DropdownMenuItem(value: 30, child: Text('30 minutes before')),
        ],
        onChanged: (v) => setState(() => _remind = v),
      ),
      const SizedBox(height: 8),
      const Text('Times are Asia/Manila. If the room code isn’t in the campus records, it’s kept exactly as typed and marked “Room location unconfirmed”.', style: TextStyle(fontSize: 12, color: muted)),
      if (_error != null) Notice(_error!),
      const SizedBox(height: 12),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save class')),
      if (_existing != null) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
          onPressed: () async {
            await AppScope.of(context).schedule.remove(_existing!.id);
            if (context.mounted) context.go('/schedule');
          },
          child: const Text('Delete class'),
        ),
      ],
    ]);
  }
}
