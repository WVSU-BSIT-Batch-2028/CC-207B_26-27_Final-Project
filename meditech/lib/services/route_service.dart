import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (client == null) {
      final straight =
          const Distance().as(LengthUnit.Meter, start, end).round();
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

    final response = await client.functions.invoke(
      'route-proxy',
      body: {
        'start': [start.longitude, start.latitude],
        'end': [end.longitude, end.latitude],
        'profile': profile,
      },
    );

    if (response.status != 200) {
      throw StateError('Failed to fetch route (${response.status})');
    }

    final data = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    final rawCoords = data['coordinates'] as List<dynamic>? ?? [];
    final points = rawCoords.map((coord) {
      final list = coord as List<dynamic>;
      return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
    }).toList();

    final rawSteps = data['steps'] as List<dynamic>? ?? [];
    final steps = rawSteps.map((raw) {
      final map = raw as Map<String, dynamic>;
      return RouteStep(
        instruction: map['instruction'] as String? ?? 'Continue',
        distanceMeters: (map['distance_meters'] as num?)?.toInt() ?? 0,
        roadName: map['road_name'] as String?,
      );
    }).toList();

    return RouteResult(
      points: points,
      distanceMeters: (data['distance_meters'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['duration_seconds'] as num?)?.toInt() ?? 0,
      steps: steps.isEmpty ? _fallbackSteps(points) : steps,
      provider: data['provider'] as String?,
    );
  }
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

List<RouteStep> _fallbackSteps(List<LatLng> points) {
  if (points.length < 2) {
    return const [RouteStep(instruction: 'Head to destination', distanceMeters: 0)];
  }
  final distance = const Distance();
  final steps = <RouteStep>[];
  for (var i = 0; i < points.length - 1; i++) {
    final segmentMeters =
        distance.as(LengthUnit.Meter, points[i], points[i + 1]).round();
    final verb = i == 0
        ? 'Head toward destination'
        : i == points.length - 2
        ? 'Arrive at pharmacy'
        : 'Continue along the route';
    steps.add(RouteStep(instruction: verb, distanceMeters: segmentMeters));
  }
  return steps;
}