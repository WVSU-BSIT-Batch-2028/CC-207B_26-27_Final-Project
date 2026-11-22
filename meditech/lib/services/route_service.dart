import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Represents route calculation results with distance and duration
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  // Polyline coordinates for map drawing
  final List<LatLng> points;

  // Total route distance in meters
  final int distanceMeters;

  // Estimated travel time in seconds
  final int durationSeconds;

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
    return '~$mins mins';
  }
}

// Service that requests directions from route-proxy Edge Function
class RouteService {
  final SupabaseClient _client;

  RouteService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  Future<RouteResult> getDirections({
    required LatLng start,
    required LatLng end,
    String profile = 'driving-car',
  }) async {
    final response = await _client.functions.invoke(
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

    return RouteResult(
      points: points,
      distanceMeters: (data['distance_meters'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}
