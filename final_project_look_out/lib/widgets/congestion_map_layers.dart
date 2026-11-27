//this is the traffic congestion marker - Joshua

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../services/congestion_predictor_service.dart';

class CongestionMapLayers {
  static Color colorForLevel(int level) {
    if (level == 2) return const Color(0xFFDC2626); // Red-600
    if (level == 1) return const Color(0xFFD97706); // Amber-600
    return const Color(0xFF16A34A); // Green-600
  }

  /// 1. Colored Corridor Polylines
  static PolylineLayer buildPolylines(List<CorridorPrediction> predictions) {
    return PolylineLayer(
      polylines: predictions.map((p) {
        return Polyline(
          points: p.segmentPoints,
          strokeWidth: p.level == 2 ? 7.0 : 5.0,
          color: colorForLevel(p.level).withValues(alpha: 0.85),
        );
      }).toList(),
    );
  }

  /// 2. Bottleneck Zone Geofence Circles (Highlighted on Moderate/Heavy zones)
  static CircleLayer buildZones(List<CorridorPrediction> predictions) {
    return CircleLayer(
      circles: predictions.where((p) => p.level > 0).map((p) {
        final color = colorForLevel(p.level);
        return CircleMarker(
          point: p.center,
          radius: p.level == 2 ? 260 : 180,
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.18),
          borderColor: color,
          borderStrokeWidth: 2.0,
        );
      }).toList(),
    );
  }

  /// 3. Interactive Map Badges (Shows ETA delay for Commuters & Pacing warning for Drivers)
  static MarkerLayer buildBadges({
    required List<CorridorPrediction> predictions,
    required bool isDriverView,
    required Function(CorridorPrediction) onTapCorridor,
  }) {
    return MarkerLayer(
      markers: predictions.map((p) {
        final color = colorForLevel(p.level);
        final badgeText = isDriverView
            ? (p.level == 2 ? 'HOLD PACE (+${p.extraDelayMins}m)' : p.label)
            : (p.extraDelayMins > 0 ? '+${p.extraDelayMins} min ETA' : 'Clear');

        return Marker(
          point: p.center,
          width: 135,
          height: 36,
          child: GestureDetector(
            onTap: () => onTapCorridor(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 1.8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    p.level == 2 ? Icons.warning_rounded : Icons.traffic_rounded,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      badgeText,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}