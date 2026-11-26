import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart' show DataStatus;
import '../data/processes_repository.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show Unconfirmed;

const _demoNotice = 'Supabase is not configured. Showing DEMO records, not official WVSU information.';

class ProcessListScreen extends StatefulWidget {
  const ProcessListScreen({super.key, this.query = ''});
  final String query;
  @override
  State<ProcessListScreen> createState() => _ProcessListScreenState();
}

class _ProcessListScreenState extends State<ProcessListScreen> {
  late final _c = TextEditingController(text: widget.query);
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final q = widget.query.trim();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('What do you need to process?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const Text('Clear steps for common student transactions.', style: TextStyle(color: muted)),
      const SizedBox(height: 10),
      TextField(
        controller: _c,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => context.go(v.trim().isEmpty ? '/processes' : '/processes?q=${Uri.encodeQueryComponent(v.trim())}'),
        decoration: InputDecoration(hintText: 'Search student processes', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line))),
      ),
      Loader<List<ProcessGuide>>(
        loadKey: q,
        what: 'process guides',
        load: () => scope.processes.list(q),
        builder: (context, list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (scope.processes.isDemo) const Notice(_demoNotice),
          if (list.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.isEmpty ? 'No process guides published yet' : 'No guide matches “$q”', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Only guides verified by the university are shown. Ask the office directly, or try the Directory.', style: TextStyle(color: muted)),
            ]))),
          for (final p in list)
            Card(
              child: ListTile(
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: blueSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.description_outlined, color: wayBlue)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${p.steps.length} steps${p.isDemo ? ' · Demo' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/processes/${p.id}'),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class ProcessDetailScreen extends StatefulWidget {
  const ProcessDetailScreen({super.key, required this.processId});
  final String processId;
  @override
  State<ProcessDetailScreen> createState() => _ProcessDetailScreenState();
}

class _ProcessDetailScreenState extends State<ProcessDetailScreen> {
  Set<int> _done = {};
  late Future<ProcessGuide?> _future;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _load();
  }

  void _load() {
    final scope = AppScope.of(context);
    _future = scope.processes.get(widget.processId);
    scope.progress.get(widget.processId).then((d) => mounted ? setState(() => _done = d) : null);
  }

  Future<void> _toggle(int pos) async {
    final d = await AppScope.of(context).progress.toggle(widget.processId, pos);
    if (mounted) setState(() => _done = d);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProcessGuide?>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [LoadError(what: 'this guide', onRetry: () => setState(_load))]);
        }
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final p = snap.data;
        if (p == null) {
          return ListView(padding: const EdgeInsets.all(16), children: const [
            Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Guide not available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
          ]);
        }
        final current = p.steps.where((s) => !_done.contains(s.position)).firstOrNull;
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextButton.icon(onPressed: () => context.go('/processes'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Processes')),
              const Text('STUDENT PROCESS', style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: wayBlue, fontWeight: FontWeight.w700)),
              Row(children: [
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
                StatusBadge(p.isDemo ? DataStatus.demo : DataStatus.verified),
              ]),
              if (p.summary != null) Text(p.summary!, style: const TextStyle(color: muted)),
              if (p.isDemo) const Notice(_demoNotice),
              Card(
                color: goldSoft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('BEFORE YOU START', style: TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
                    if (p.beforeYouStart != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(p.beforeYouStart!)),
                    for (final n in p.notes) Text(n),
                    const SizedBox(height: 8),
                    const Text('Required documents', style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final d in p.documents) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.circle, size: 7, color: gold), const SizedBox(width: 8), Expanded(child: Text(d))])),
                  ]),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_done.length} of ${p.steps.length} steps completed', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: p.steps.isEmpty ? 0 : _done.length / p.steps.length, minHeight: 8, borderRadius: BorderRadius.circular(8), backgroundColor: blueSoft),
                  ]),
                ),
              ),
              for (final s in p.steps) _StepTile(step: s, done: _done.contains(s.position), current: current?.position == s.position, onToggle: () => _toggle(s.position)),
            ]),
          ),
          if (current != null)
            Material(
              elevation: 8,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('NEXT STEP', style: TextStyle(fontSize: 11, letterSpacing: 1, color: wayBlue, fontWeight: FontWeight.w700)),
                  Text(current.title, key: const Key('next-step-title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(current.action, style: const TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (current.officePlaceId != null)
                      Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink), onPressed: () => context.go('/map?to=${Uri.encodeQueryComponent(current.officePlaceId!)}'), child: const Text('Take me there'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(key: const Key('mark-next'), onPressed: () => _toggle(current.position), child: const Text('Mark step complete'))),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.done, required this.current, required this.onToggle});
  final ProcessStep step;
  final bool done, current;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('STEP ${step.position}', style: const TextStyle(fontSize: 11, letterSpacing: .8, color: muted, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (current) const _Tag('Current', goldSoft, Color(0xFF8A5A00)),
        if (done) const _Tag('Done', Color(0xFFDFF5E6), Color(0xFF11663A)),
      ]),
      Text(step.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: done ? muted : ink)),
      Text(step.action, style: const TextStyle(color: muted)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        if (step.officePlaceId != null)
          (current ? FilledButton.icon : OutlinedButton.icon)(
            onPressed: () => context.go('/map?to=${Uri.encodeQueryComponent(step.officePlaceId!)}'),
            icon: const Icon(Icons.place_outlined, size: 18),
            label: const Text('Show office on map'),
          )
        else
          const Unconfirmed('Office location unconfirmed'),
        OutlinedButton(onPressed: onToggle, child: Text(done ? 'Mark not done' : 'Mark step complete')),
      ]),
    ]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30, height: 30, margin: const EdgeInsets.only(top: 14, right: 10),
        decoration: BoxDecoration(shape: BoxShape.circle, color: current ? wayBlue : done ? const Color(0xFFDFF5E6) : Colors.white, border: Border.all(color: current ? wayBlue : line, width: 2)),
        alignment: Alignment.center,
        child: done ? const Icon(Icons.check, size: 16, color: Color(0xFF11663A)) : Text('${step.position}', style: TextStyle(color: current ? Colors.white : muted, fontWeight: FontWeight.w700)),
      ),
      Expanded(child: current ? Card(child: Padding(padding: const EdgeInsets.all(14), child: body)) : Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: body)),
    ]);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
