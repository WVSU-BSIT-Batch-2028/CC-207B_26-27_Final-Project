import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_maneuver_instructions.dart';

// Provides RouteService (overridable in widget tests)
final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService();
});

// One turn-by-turn step along the route
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    this.roadName,
  });

  final String instruction;
  final int distanceMeters;
  final String? roadName;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

// Represents route calculation results with distance and duration
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
    this.provider,
  });

  // Polyline coordinates for map drawing
  final List<LatLng> points;

  // Total route distance in meters
  final int distanceMeters;

  // Estimated travel time in seconds
  final int durationSeconds;

  final List<RouteStep> steps;

  final String? provider;

  double get distanceKm => distanceMeters / 1000;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final mins = (durationSeconds / 60).round();
    if (mins <= 1) return '~1 min';
    return '~$mins min';
  }
}

// Service that requests directions from route-proxy Edge Function
class RouteService {
  final SupabaseClient? _client;

  RouteService([this._client]);

  SupabaseClient? _resolveClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<RouteResult> getDirections({
    required LatLng start,
    required LatLng end,
    String profile = 'driving-car',
  }) async {
    final client = _resolveClient();

    if (client != null) {
      try {
        final response = await client.functions.invoke(
          'route-proxy',
          body: {
            'start': [start.longitude, start.latitude],
            'end': [end.longitude, end.latitude],
            'profile': profile,
          },
        );

        if (response.status == 200) {
          final result = _parseProxyPayload(response.data);
          if (result.provider != 'local_fallback') {
            return _applyProfileDuration(result, profile);
          }
        }
      } catch (_) {
        // Fall through to direct OSRM.
      }
    }

    final osrm = await _fetchOsrmRoadRoute(
      start: start,
      end: end,
      profile: profile,
    );
    if (osrm != null) {
      return _applyProfileDuration(osrm, profile);
    }

    return _applyProfileDuration(
      _estimatedFallback(start, end, profile),
      profile,
    );
  }
}

int _modeledDurationSeconds(int meters, String profile) {
  final metersPerSecond = switch (profile) {
    'foot-walking' => 1.33,
    'cycling-regular' => 4.2,
    _ => 8.3,
  };
  if (meters <= 0) return 0;
  return (meters / metersPerSecond).round();
}

int _effectiveDurationSeconds(int meters, String profile, int routerSeconds) {
  final modeled = _modeledDurationSeconds(meters, profile);
  if (routerSeconds <= 0) return modeled;

  final impliedMps = meters / routerSeconds;
  final maxReasonable = switch (profile) {
    'foot-walking' => 2.2,
    'cycling-regular' => 7.5,
    _ => 30.0,
  };
  final minReasonable = switch (profile) {
    'foot-walking' => 0.7,
    'cycling-regular' => 2.0,
    _ => 1.5,
  };

  if (impliedMps > maxReasonable || impliedMps < minReasonable) {
    return modeled;
  }
  return routerSeconds;
}

RouteResult _applyProfileDuration(RouteResult result, String profile) {
  final duration = _effectiveDurationSeconds(
    result.distanceMeters,
    profile,
    result.durationSeconds,
  );
  if (duration == result.durationSeconds) return result;
  return RouteResult(
    points: result.points,
    distanceMeters: result.distanceMeters,
    durationSeconds: duration,
    steps: result.steps,
    provider: result.provider,
  );
}

RouteResult _parseProxyPayload(Object? data) {
  final map = data is String
      ? jsonDecode(data) as Map<String, dynamic>
      : data as Map<String, dynamic>;

  final rawCoords = map['coordinates'] as List<dynamic>? ?? [];
  final points = rawCoords.map((coord) {
    final list = coord as List<dynamic>;
    return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
  }).toList();

  final rawSteps = map['steps'] as List<dynamic>? ?? [];
  final steps = rawSteps.map((raw) {
    final step = raw as Map<String, dynamic>;
    final road = step['road_name'] as String? ?? '';
    final maneuver = step['maneuver'] as Map<String, dynamic>?;
    final instruction = maneuver != null
        ? osrmManeuverInstruction(maneuver: maneuver, roadName: road)
        : _polishGenericInstruction(
            step['instruction'] as String? ?? 'Continue',
            road,
          );
    return RouteStep(
      instruction: instruction,
      distanceMeters: (step['distance_meters'] as num?)?.toInt() ?? 0,
      roadName: road.isEmpty ? null : road,
    );
  }).toList();

  return RouteResult(
    points: points,
    distanceMeters: (map['distance_meters'] as num?)?.toInt() ?? 0,
    durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
    steps: steps.isEmpty ? _fallbackSteps(points) : steps,
    provider: map['provider'] as String?,
  );
}

Future<RouteResult?> _fetchOsrmRoadRoute({
  required LatLng start,
  required LatLng end,
  required String profile,
}) async {
  final coords =
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
  final query =
      '?overview=full&geometries=geojson&steps=true&annotations=false';
  final uriCandidates = switch (profile) {
    'foot-walking' => [
      Uri.parse(
        'https://routing.openstreetmap.de/routed-foot/route/v1/foot/$coords$query',
      ),
      Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/$coords$query',
      ),
    ],
    'cycling-regular' => [
      Uri.parse(
        'https://routing.openstreetmap.de/routed-bike/route/v1/bike/$coords$query',
      ),
      Uri.parse(
        'https://router.project-osrm.org/route/v1/bike/$coords$query',
      ),
    ],
    _ => [
      Uri.parse(
        'https://routing.openstreetmap.de/routed-car/route/v1/driving/$coords$query',
      ),
      Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords$query',
      ),
    ],
  };

  http.Response? response;
  for (final uri in uriCandidates) {
    try {
      response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) break;
      response = null;
    } catch (_) {
      response = null;
    }
  }
  if (response == null) return null;

  try {
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final route = (data['routes'] as List<dynamic>?)?.first;
    if (route is! Map<String, dynamic>) return null;

    final geometry = route['geometry'] as Map<String, dynamic>?;
    final rawCoords = geometry?['coordinates'] as List<dynamic>? ?? [];
    if (rawCoords.isEmpty) return null;

    final points = rawCoords.map((coord) {
      final list = coord as List<dynamic>;
      return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
    }).toList();

    final legs = route['legs'] as List<dynamic>? ?? [];
    final steps = <RouteStep>[];
    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final rawSteps = legMap['steps'] as List<dynamic>? ?? [];
      for (final raw in rawSteps) {
        final step = raw as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        final name = step['name'] as String? ?? '';
        final instruction = osrmManeuverInstruction(
          maneuver: maneuver,
          roadName: name,
        );
        steps.add(
          RouteStep(
            instruction: instruction,
            distanceMeters: (step['distance'] as num?)?.round() ?? 0,
            roadName: name.isEmpty ? null : name,
          ),
        );
      }
    }

    return RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num?)?.round() ?? 0,
      durationSeconds: (route['duration'] as num?)?.round() ?? 0,
      steps: steps.isEmpty ? _fallbackSteps(points) : steps,
      provider: 'osrm',
    );
  } catch (_) {
    return null;
  }
}

RouteResult _estimatedFallback(LatLng start, LatLng end, String profile) {
  final straight = const Distance().as(LengthUnit.Meter, start, end).round();
  final meters = (straight * 1.3).round();
  final speedMps = switch (profile) {
    'foot-walking' => 1.33,
    'cycling-regular' => 4.2,
    _ => 8.3,
  };
  final points = _fallbackPolyline(start, end);
  return RouteResult(
    points: points,
    distanceMeters: meters,
    durationSeconds: (meters / speedMps).round(),
    steps: _fallbackSteps(points),
    provider: 'local_fallback',
  );
}

List<LatLng> _fallbackPolyline(LatLng start, LatLng end) {
  final midLng = (start.longitude + end.longitude) / 2;
  final midLat = (start.latitude + end.latitude) / 2;
  return [
    start,
    LatLng(start.latitude, midLat),
    LatLng(midLng, midLat),
    LatLng(end.latitude, midLat),
    end,
  ];
}

String _polishGenericInstruction(String instruction, String roadName) {
  final lower = instruction.toLowerCase();
  if (_looksGenericContinue(lower) && roadName.isNotEmpty) {
    return 'Go straight on $roadName';
  }
  return instruction;
}

bool _looksGenericContinue(String lower) {
  return lower == 'continue' ||
      lower.startsWith('continue on') ||
      lower == 'head';
}

List<RouteStep> _fallbackSteps(List<LatLng> points) {
  final segments = polylineTurnSteps(points);
  return [
    for (final segment in segments)
      RouteStep(
        instruction: segment.instruction,
        distanceMeters: segment.distanceMeters,
      ),
  ];
}