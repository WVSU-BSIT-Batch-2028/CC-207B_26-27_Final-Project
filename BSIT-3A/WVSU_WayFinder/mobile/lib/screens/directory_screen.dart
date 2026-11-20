import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/faculty_repository.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show Unconfirmed;

const _cats = [('all', 'All'), ('faculty', 'Faculty'), ('building', 'Buildings'), ('room', 'Rooms'), ('office', 'Offices'), ('college', 'Colleges')];
const _demoNotice = 'Supabase is not configured. Showing DEMO records, not official WVSU information.';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, this.query = '', this.category = 'all'});
  final String query;
  final String category;
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  late final _controller = TextEditingController(text: widget.query);

  void _go({String? q, String? cat}) {
    final p = <String, String>{};
    final nq = q ?? widget.query, nc = cat ?? widget.category;
    if (nq.isNotEmpty) p['q'] = nq;
    if (nc != 'all') p['cat'] = nc;
    context.go(Uri(path: '/directory', queryParameters: p.isEmpty ? null : p).toString());
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final q = widget.query.trim();
    final cat = widget.category;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Directory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const Text('Teachers, buildings, rooms and offices.', style: TextStyle(color: muted)),
      const SizedBox(height: 8),
      TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => _go(q: v.trim()),
        decoration: InputDecoration(hintText: 'Search teachers, rooms, offices', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line))),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (id, label) in _cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(label), selected: cat == id, onSelected: (_) => _go(cat: id), selectedColor: wayBlue, labelStyle: TextStyle(color: cat == id ? Colors.white : ink)),
            ),
        ]),
      ),
      if (cat == 'all' || cat == 'faculty') ...[
        const _Section('FACULTY'),
        Loader<List<Faculty>>(
          loadKey: 'f:$q',
          what: 'faculty profiles',
          load: () => scope.faculty.search(q),
          builder: (context, rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (scope.faculty.isDemo) const Notice(_demoNotice),
            if (rows.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(q.isEmpty ? 'No verified faculty profiles yet.' : 'No teacher matches “$q”', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
            for (final f in rows)
              Card(
                child: ListTile(
                  title: Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([f.positionTitle, f.department].whereType<String>().join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/directory/faculty/${Uri.encodeComponent(f.recordId)}'),
                ),
              ),
          ]),
        ),
      ],
      if (cat != 'faculty') ...[
        _Section(cat == 'all' ? 'BUILDINGS, ROOMS AND OFFICES' : _cats.firstWhere((c) => c.$1 == cat).$2.toUpperCase()),
        Loader<List<PlaceView>>(
          loadKey: 'p',
          what: 'buildings, rooms and offices',
          load: scope.places.list,
          builder: (context, all) {
            final n = q.toLowerCase();
            final rows = all.where((v) => (cat == 'all' || v.place.kind == cat) && (n.isEmpty || '${v.place.name} ${v.place.roomCode ?? ''}'.toLowerCase().contains(n))).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rows.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(q.isEmpty ? 'No verified places yet.' : 'No place matches “$q”', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
              for (final v in rows)
                Card(
                  child: ListTile(
                    title: Text(v.place.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([v.place.kind, v.place.roomCode, v.parent?.name].whereType<String>().join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/place/${Uri.encodeComponent(v.place.id)}'),
                  ),
                ),
            ]);
          },
        ),
      ],
    ]);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 11, letterSpacing: 1, color: muted, fontWeight: FontWeight.w700)),
      );
}

class FacultyDetailScreen extends StatelessWidget {
  const FacultyDetailScreen({super.key, required this.recordId});
  final String recordId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextButton.icon(onPressed: () => context.go('/directory'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Directory')),
      Loader<Faculty?>(
        loadKey: recordId,
        what: 'this profile',
        load: () => scope.faculty.get(recordId),
        builder: (context, f) {
          if (f == null) {
            return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Profile not available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))));
          }
          return FacultyDetailCard(faculty: f);
        },
      ),
    ]);
  }
}

class FacultyDetailCard extends StatelessWidget {
  const FacultyDetailCard({super.key, required this.faculty});
  final Faculty faculty;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final f = faculty;
    Widget fact(String k, String? v) => v == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 84, child: Text(k.toUpperCase(), style: const TextStyle(fontSize: 11, color: muted, letterSpacing: .6))),
              Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('FACULTY', style: TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
            StatusBadge(f.isDemo ? DataStatus.demo : DataStatus.verified),
          ]),
          const SizedBox(height: 6),
          Text(f.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          fact('Position', f.positionTitle),
          fact('Dept.', f.department),
          fact('College', f.collegeUnit == null ? null : '${f.collegeUnit}${f.collegeCode != null ? ' (${f.collegeCode})' : ''}'),
          const SizedBox(height: 10),
          // Show on map only when a verified (demo, in demo mode) office with a location exists.
          if (f.officePlaceId == null)
            const Unconfirmed('Office location unconfirmed')
          else
            Loader<PlaceView?>(
              loadKey: f.officePlaceId!,
              what: 'the office location',
              load: () => scope.places.getPlace(f.officePlaceId!),
              builder: (context, v) {
                final ok = v != null && v.hasPoint && (v.place.status == DataStatus.verified || (f.isDemo && v.place.status == DataStatus.demo));
                if (!ok) return const Unconfirmed('Office location unconfirmed');
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  fact('Office', [v.place.name, v.parent?.name, v.place.floor != null ? 'Floor ${v.place.floor}' : null].whereType<String>().join(' · ')),
                  const SizedBox(height: 6),
                  FilledButton.icon(onPressed: () => context.go('/map?to=${Uri.encodeQueryComponent(v.place.id)}'), icon: const Icon(Icons.place_outlined, size: 18), label: const Text('Show on map')),
                ]);
              },
            ),
        ]),
      ),
    );
  }
}
