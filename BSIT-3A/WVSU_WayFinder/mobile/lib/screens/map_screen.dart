import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/campus.dart';
import '../data/location_service.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show Unconfirmed;

// Approximate WVSU Main Campus centre (Wikipedia: 10.7161 N, 122.5614 E). Not surveyed.
const campusCenter = LatLng(10.7161, 122.5614);
const campusRadiusM = 900.0;

/// A room or office is reached through its building; a building is its own destination.
Place? buildingOf(PlaceView? v) => v == null ? null : (v.place.kind == 'building' ? v.place : v.parent);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.to = '', this.from = ''});
  final String to;
  final String from;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  PlaceView? _dest, _start;
  CampusPaths? _paths;
  List<PlaceView> _all = const [];
  bool _loading = true, _destFailed = false, _pathsFailed = false, _tilesFailed = false, _locating = false;
  LocationFix? _fix;
  String? _locProblem;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _load();
    }
  }

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to || old.from != widget.from) _load();
  }

  Future<void> _load() async {
    final s = AppScope.of(context);
    setState(() { _loading = true; _destFailed = false; _pathsFailed = false; });
    Future<T?> safe<T>(Future<T> f, void Function() onFail) async {
      try { return await f; } catch (_) { onFail(); return null; }
    }
    final dest = widget.to.isEmpty ? null : await safe(s.places.getPlace(widget.to), () => _destFailed = true);
    final start = widget.from.isEmpty || widget.from == 'gps' ? null : await safe(s.places.getPlace(widget.from), () {});
    final paths = await safe(s.campus.load(), () => _pathsFailed = true);
    final all = await safe(s.places.list(), () {}) ?? const <PlaceView>[];
    if (!mounted) return;
    setState(() { _dest = dest; _start = start; _paths = paths; _all = all; _loading = false; });
  }

  /// Destination stays in the URL; switching the start only changes `from`.
  void _setFrom(String from) => context.go(Uri(path: '/map', queryParameters: {if (widget.to.isNotEmpty) 'to': widget.to, if (from.isNotEmpty) 'from': from}).toString());

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final out = await AppScope.of(context).location.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _fix = out.fix;
      _locProblem = out.failure == null ? null : describeFailure(out.failure!);
    });
    if (out.fix != null) _setFrom('gps');
  }

  Future<void> _chooseStart() async {
    final options = _all.where((v) => ['building', 'room', 'office'].contains(v.place.kind) && (v.hasPoint || v.place.kind == 'building')).toList();
    final picked = await showModalBottomSheet<PlaceView>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .6,
          child: options.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No building or room with a recorded location is available yet.'))
              : ListView(children: [
                  const Padding(padding: EdgeInsets.all(16), child: Text('Choose starting point', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                  for (final v in options)
                    ListTile(
                      title: Text(v.place.roomCode ?? v.place.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([v.place.roomCode != null ? v.place.name : v.place.kind, v.parent?.name].whereType<String>().join(' · ')),
                      onTap: () => Navigator.pop(ctx, v),
                    ),
                ]),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() { _fix = null; _locProblem = null; });
      _setFrom(picked.place.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final cfg = scope.config;
    final dest = _dest, paths = _paths;
    final destB = buildingOf(dest);
    final destPoint = dest != null && dest.hasPoint ? LatLng(dest.lat!, dest.lng!) : null;
    final fix = _fix;
    final gpsPoor = fix != null && fix.accuracyMeters > 50;
    final offCampus = fix != null && distanceM(fix.lng, fix.lat, campusCenter.longitude, campusCenter.latitude) > campusRadiusM;
    final gpsNode = fix != null && paths != null && !gpsPoor && !offCampus ? snapToNode(paths, fix.lng, fix.lat) : null;
    final startB = buildingOf(_start);

    ({WalkRoute route, Entrance entrance})? plan;
    if (paths != null && destB != null) {
      if (widget.from == 'gps' && gpsNode != null) plan = routeBetween(paths, fromNodeId: gpsNode.id, toBuildingId: destB.id);
      if (widget.from.isNotEmpty && widget.from != 'gps' && startB != null) plan = routeBetween(paths, fromBuildingId: startB.id, toBuildingId: destB.id);
    }
    String? problem;
    if (widget.to.isNotEmpty && dest != null) {
      if (destB == null) {
        problem = 'This place isn’t linked to a building with a recorded location yet, so no walking route can be drawn.';
      } else if (paths != null && entrancesOf(paths, destB.id).isEmpty) {
        problem = 'No verified entrance is recorded for ${destB.name} yet.';
      } else if (widget.from.isEmpty) {
        problem = 'Choose where you’re starting from to get walking directions.';
      } else if (widget.from == 'gps' && fix == null) {
        problem = 'Tap “Use my location” again, or choose a starting point.';
      } else if (widget.from == 'gps' && !gpsPoor && !offCampus && gpsNode == null) {
        problem = 'You’re not near a verified walkway. Choose a starting building or room instead.';
      } else if (startB != null && startB.id == destB.id) {
        problem = 'You’re already in this building.';
      } else if (plan == null && paths != null && !(widget.from == 'gps' && (gpsPoor || offCampus))) {
        problem = 'No verified walking route connects these places yet.';
      }
    }
    final floorPlans = paths != null && destB != null && dest?.place.floor != null
        ? paths.floorPlans.where((f) => f.buildingId == destB.id && f.floor == dest!.place.floor).toList()
        : <FloorPlan>[];
    final startPoint = widget.from == 'gps' && fix != null ? LatLng(fix.lat, fix.lng) : (_start != null && _start!.hasPoint ? LatLng(_start!.lat!, _start!.lng!) : null);
    final routePts = plan?.route.points.map((p) => LatLng(p.$2, p.$1)).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Campus Map', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      if (scope.places.isDemo) const Notice('Supabase is not configured. Showing DEMO places and walkways, not official WVSU information.'),
      if (!cfg.hasMapTiler) const Notice('No MapTiler key set. Showing the campus overlay only.', info: true),
      if (cfg.hasMapTiler && _tilesFailed) const Notice('MapTiler basemap unavailable. Showing the campus overlay only.', info: true),
      if (_destFailed) LoadError(what: 'this destination', onRetry: _load),
      if (_pathsFailed) LoadError(what: 'walking paths', onRetry: _load),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 300,
          child: FlutterMap(
            key: ValueKey('${destPoint ?? ''}|${routePts?.length}|$startPoint'),
            options: MapOptions(
              initialCenter: routePts?.isNotEmpty == true ? routePts![routePts.length ~/ 2] : (destPoint ?? campusCenter),
              initialZoom: destPoint == null ? 16.5 : 18,
              backgroundColor: const Color(0xFFE6EDF7),
            ),
            children: [
              if (cfg.hasMapTiler && !_tilesFailed)
                TileLayer(
                  urlTemplate: 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=${cfg.mapTilerKey}',
                  userAgentPackageName: 'ph.edu.wvsu.wayfinder',
                  errorTileCallback: (tile, error, stack) { if (!_tilesFailed && mounted) setState(() => _tilesFailed = true); },
                ),
              if (routePts != null) PolylineLayer(polylines: [Polyline(points: routePts, strokeWidth: 6, color: navy)]),
              MarkerLayer(markers: [
                for (final v in _all)
                  if (v.place.kind == 'building' && v.place.hasPoint && v.place.id != destB?.id)
                    Marker(point: LatLng(v.place.lat!, v.place.lng!), width: 18, height: 18, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: wayBlue, width: 3)))),
                if (paths != null && destB != null)
                  for (final e in entrancesOf(paths, destB.id))
                    Marker(point: LatLng(e.lat, e.lng), width: 14, height: 14, child: Container(decoration: BoxDecoration(color: gold, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                if (destPoint != null) Marker(point: destPoint, width: 44, height: 44, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: navy, size: 44, semanticLabel: 'Destination')),
                if (startPoint != null) Marker(point: startPoint, width: 26, height: 26, child: const Icon(Icons.my_location, color: wayBlue, semanticLabel: 'Start')),
              ]),
            ],
          ),
        ),
      ),
      if (_loading) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      if (widget.to.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Search for a room or building to get directions.', style: TextStyle(color: muted)))),
      if (!_loading && widget.to.isNotEmpty && dest == null && !_destFailed)
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No place has the ID “${widget.to}”.'))),
      if (dest != null) ...[
        Card(
          key: const Key('dest-card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('DESTINATION', style: TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
                StatusBadge(dest.place.status),
              ]),
              const SizedBox(height: 4),
              Text(destB?.name ?? dest.place.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              if (dest.place.kind != 'building' && destB != null)
                Text('Walk to this building, then go inside to ${dest.place.roomCode ?? dest.place.name}.', style: const TextStyle(fontSize: 13, color: muted)),
              if (plan != null) Text('Enter at: ${plan.entrance.name}', style: const TextStyle(fontSize: 13)),
              if (destPoint == null) const Padding(padding: EdgeInsets.only(top: 6), child: Unconfirmed('Location unconfirmed')),
            ]),
          ),
        ),
        if (dest.place.kind != 'building')
          Card(
            key: const Key('inside-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('INSIDE THE BUILDING', style: TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (dest.place.roomCode != null) Text('Room ${dest.place.roomCode}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
                if (dest.place.kind != 'room') Text(dest.place.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Floor ${dest.place.floor ?? 'not recorded'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final f in floorPlans)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: f.imageUrl.startsWith('/demo/')
                            ? Image.asset('assets/demo/${f.imageUrl.split('/').last.replaceAll('.svg', '.png')}', semanticLabel: f.label)
                            : Image.network(f.imageUrl, semanticLabel: f.label, errorBuilder: (_, __, ___) => const Text('Floor plan image could not be loaded.')),
                      ),
                      Text(f.label ?? 'Floor ${f.floor}', style: const TextStyle(fontSize: 12, color: muted)),
                    ]),
                  ),
                if (paths != null && floorPlans.isEmpty) const Text('No floor plan is available for this floor.', style: TextStyle(fontSize: 12, color: muted)),
              ]),
            ),
          ),
        Card(
          key: const Key('route-card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('WALKING ROUTE', style: TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (plan != null)
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${plan.route.minutes} min', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  TextSpan(text: ' walk · ${plan.route.meters.round()} m  '),
                  const TextSpan(text: '(≈ estimate, verified walkways only)', style: TextStyle(fontSize: 12, color: muted)),
                ]))
              else if (problem != null)
                Text(problem, style: const TextStyle(color: muted)),
              const SizedBox(height: 10),
              const Text('STARTING FROM', style: TextStyle(fontSize: 11, letterSpacing: .8, color: muted, fontWeight: FontWeight.w700)),
              Text(
                widget.from == 'gps' && fix != null
                    ? 'My location · accuracy ±${fix.accuracyMeters.round()} m (${fix.accuracyLabel})'
                    : _start != null ? '${_start!.place.roomCode ?? _start!.place.name}${_start!.parent != null ? ' · ${_start!.parent!.name}' : ''}' : 'Not set',
                key: const Key('start-line'),
              ),
              if (_locProblem != null) Notice('$_locProblem Choose a starting building or room instead.'),
              if (gpsPoor) Notice('GPS accuracy is poor (±${fix.accuracyMeters.round()} m). Choose a starting building or room for reliable directions.'),
              if (offCampus && !gpsPoor) const Notice('You appear to be outside the campus. Choose a starting building or room.'),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(onPressed: _locating ? null : _useMyLocation, icon: const Icon(Icons.my_location, size: 18), label: Text(_locating ? 'Locating…' : 'Use my location')),
                OutlinedButton(onPressed: _chooseStart, child: const Text('Choose starting point')),
              ]),
            ]),
          ),
        ),
      ],
    ]);
  }
}
