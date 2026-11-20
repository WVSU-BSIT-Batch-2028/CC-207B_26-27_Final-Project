import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import 'places_repository.dart' show PlacesException;

class ProcessStep {
  const ProcessStep(this.position, this.officePlaceId, this.title, this.action);
  final int position;
  final String? officePlaceId;
  final String title, action;
}

class ProcessGuide {
  const ProcessGuide({required this.id, required this.name, this.summary, this.beforeYouStart, required this.documents, required this.notes, required this.steps, required this.isDemo});
  final String id, name;
  final String? summary, beforeYouStart;
  final List<String> documents, notes;
  final List<ProcessStep> steps;
  final bool isDemo;
}

abstract class ProcessesRepository {
  bool get isDemo;
  Future<List<ProcessGuide>> list(String query);
  Future<ProcessGuide?> get(String id);
}

ProcessGuide _parse(Map<String, dynamic> j, {required bool demo}) {
  final reqs = ((demo ? j['requirements'] : j['process_requirements']) as List? ?? []).cast<Map<String, dynamic>>()
    ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
  final steps = ((demo ? j['steps'] : j['process_steps']) as List? ?? []).cast<Map<String, dynamic>>()
    ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
  return ProcessGuide(
    id: j['id'] as String,
    name: j['name'] as String,
    summary: j['summary'] as String?,
    beforeYouStart: (demo ? j['beforeYouStart'] : j['before_you_start']) as String?,
    documents: [for (final r in reqs) if (r['kind'] == 'document') r['text'] as String],
    notes: [for (final r in reqs) if (r['kind'] == 'note') r['text'] as String],
    steps: [for (final s in steps) ProcessStep(s['position'] as int, (demo ? s['officePlaceId'] : s['office_place_id']) as String?, s['title'] as String, s['action'] as String)],
    isDemo: demo,
  );
}

class LiveProcessesRepository implements ProcessesRepository {
  LiveProcessesRepository(this.config, {http.Client? client}) : _client = client ?? http.Client();
  final AppConfig config;
  final http.Client _client;
  static const _select = 'select=id,name,summary,before_you_start,process_requirements(position,kind,text),process_steps(position,office_place_id,title,action)';
  @override
  bool get isDemo => false;

  Future<List<ProcessGuide>> _get(String filter) async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse('${config.restBase}/processes?$_select&is_published=eq.true&status=eq.verified$filter&order=name.asc'),
          headers: {'apikey': config.supabasePublishableKey, 'Accept': 'application/json'});
    } catch (_) {
      throw PlacesException('network error');
    }
    if (res.statusCode != 200) throw PlacesException('HTTP ${res.statusCode}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>().map((j) => _parse(j, demo: false)).toList();
  }

  @override
  Future<List<ProcessGuide>> list(String query) {
    final q = query.replaceAll(RegExp(r'[*,()\\]'), ' ').trim();
    return _get(q.isEmpty ? '' : '&name=ilike.*${Uri.encodeQueryComponent(q)}*');
  }

  @override
  Future<ProcessGuide?> get(String id) async => (await _get('&id=eq.${Uri.encodeQueryComponent(id)}')).firstOrNull;
}

/// DEMO procedures (copy of the web fixture). Only when Supabase is not configured.
class DemoProcessesRepository implements ProcessesRepository {
  DemoProcessesRepository({Future<String> Function()? loader}) : _loader = loader ?? (() => rootBundle.loadString('assets/demo/processes.json'));
  final Future<String> Function() _loader;
  @override
  bool get isDemo => true;

  Future<List<ProcessGuide>> _all() async =>
      ((jsonDecode(await _loader()) as Map)['processes'] as List).cast<Map<String, dynamic>>().map((j) => _parse(j, demo: true)).toList();

  @override
  Future<List<ProcessGuide>> list(String query) async {
    final q = query.trim().toLowerCase();
    return (await _all()).where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.summary ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Future<ProcessGuide?> get(String id) async => (await _all()).where((p) => p.id == id).firstOrNull;
}

ProcessesRepository createProcessesRepository(AppConfig c) => c.isLive ? LiveProcessesRepository(c) : DemoProcessesRepository();

/// Completed steps per process, saved on this device.
class ProgressStore {
  static const _key = 'wf.process.progress.v1';
  Future<Set<int>> get(String processId) async {
    final p = await SharedPreferences.getInstance();
    final m = jsonDecode(p.getString(_key) ?? '{}') as Map<String, dynamic>;
    return {...((m[processId] as List?) ?? []).cast<int>()};
  }

  Future<Set<int>> toggle(String processId, int position) async {
    final p = await SharedPreferences.getInstance();
    final m = jsonDecode(p.getString(_key) ?? '{}') as Map<String, dynamic>;
    final done = {...((m[processId] as List?) ?? []).cast<int>()};
    done.contains(position) ? done.remove(position) : done.add(position);
    m[processId] = (done.toList()..sort());
    await p.setString(_key, jsonEncode(m));
    return done;
  }
}
