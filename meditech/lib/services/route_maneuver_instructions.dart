import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Builds short, Waze-style instructions from OSRM maneuver fields.
String osrmManeuverInstruction({
  Map<String, dynamic>? maneuver,
  String roadName = '',
}) {
  final existing = (maneuver?['instruction'] as String?)?.trim();
  if (existing != null && existing.isNotEmpty && _looksLikeTurn(existing)) {
    return existing;
  }

  final type = (maneuver?['type'] as String?) ?? '';
  final modifier = (maneuver?['modifier'] as String?) ?? '';
  final road = roadName.trim();
  final onto = road.isEmpty ? '' : ' onto $road';

  switch (type) {
    case 'depart':
      if (road.isNotEmpty) return 'Start on $road';
      return _turnPhrase(modifier, fallback: 'Head toward your route');
    case 'arrive':
      return 'You have arrived at your destination';
    case 'turn':
    case 'end of road':
      return '${_turnPhrase(modifier)}$onto';
    case 'fork':
      return '${_forkPhrase(modifier)}$onto';
    case 'merge':
      return 'Merge ${_mergeModifier(modifier)}$onto'.trim();
    case 'on ramp':
      return 'Take the ramp$onto';
    case 'off ramp':
      return 'Take the exit$onto';
    case 'roundabout':
    case 'rotary':
    case 'roundabout turn':
      return _roundaboutPhrase(modifier, onto);
    case 'exit roundabout':
    case 'exit rotary':
      return 'Exit the roundabout$onto';
    case 'new name':
    case 'continue':
    case 'notification':
      if (modifier.isNotEmpty && modifier != 'straight') {
        return '${_turnPhrase(modifier)}$onto';
      }
      if (road.isNotEmpty) return 'Go straight on $road';
      return 'Go straight';
    default:
      if (existing != null && existing.isNotEmpty) return existing;
      if (road.isNotEmpty) return 'Continue on $road';
      return 'Continue';
  }
}

String _turnPhrase(String modifier, {String fallback = 'Continue'}) {
  return switch (modifier) {
    'uturn' => 'Make a U-turn',
    'sharp right' => 'Turn sharp right',
    'right' => 'Turn right',
    'slight right' => 'Slight right',
    'straight' => 'Go straight',
    'slight left' => 'Slight left',
    'left' => 'Turn left',
    'sharp left' => 'Turn sharp left',
    _ => fallback,
  };
}

String _forkPhrase(String modifier) {
  return switch (modifier) {
    'left' => 'Keep left at the fork',
    'slight left' => 'Keep left at the fork',
    'right' => 'Keep right at the fork',
    'slight right' => 'Keep right at the fork',
    _ => 'Keep straight at the fork',
  };
}

String _mergeModifier(String modifier) {
  return switch (modifier) {
    'left' => 'to the left',
    'slight left' => 'to the left',
    'right' => 'to the right',
    'slight right' => 'to the right',
    _ => '',
  };
}

String _roundaboutPhrase(String modifier, String onto) {
  if (modifier.isEmpty) return 'Enter the roundabout$onto';
  return switch (modifier) {
    'left' => 'At the roundabout, take the exit on the left$onto',
    'right' => 'At the roundabout, take the exit on the right$onto',
    'slight left' => 'At the roundabout, bear left$onto',
    'slight right' => 'At the roundabout, bear right$onto',
    'straight' => 'At the roundabout, go straight$onto',
    'uturn' => 'At the roundabout, take the U-turn exit$onto',
    _ => 'At the roundabout, follow the road$onto',
  };
}

bool _looksLikeTurn(String text) {
  final lower = text.toLowerCase();
  const keys = [
    'turn',
    'left',
    'right',
    'u-turn',
    'roundabout',
    'merge',
    'ramp',
    'exit',
    'fork',
    'bear',
    'sharp',
    'straight',
    'arrive',
  ];
  return keys.any(lower.contains);
}

/// Bearing-based steps when we only have a polyline (offline / fallback route).
List<({String instruction, int distanceMeters})> polylineTurnSteps(
  List<LatLng> points,
) {
  if (points.length < 2) {
    return [(instruction: 'Head to destination', distanceMeters: 0)];
  }

  const distance = Distance();
  final out = <({String instruction, int distanceMeters})>[];

  for (var i = 0; i < points.length - 1; i++) {
    final from = points[i];
    final to = points[i + 1];
    final segmentMeters = distance.as(LengthUnit.Meter, from, to).round();

    String instruction;
    if (i == 0) {
      instruction = 'Head toward destination';
    } else if (i == points.length - 2) {
      instruction = 'Arrive at the pharmacy';
    } else {
      final prev = points[i - 1];
      final delta = _bearingDelta(
        _bearing(prev, from),
        _bearing(from, to),
      );
      if (delta >= 35) {
        instruction = 'Turn right';
      } else if (delta <= -35) {
        instruction = 'Turn left';
      } else if (delta >= 15) {
        instruction = 'Slight right';
      } else if (delta <= -15) {
        instruction = 'Slight left';
      } else {
        instruction = 'Go straight';
      }
    }
    out.add((instruction: instruction, distanceMeters: segmentMeters));
  }
  return out;
}

double _bearing(LatLng from, LatLng to) {
  final lat1 = from.latitudeInRad;
  final lat2 = to.latitudeInRad;
  final dLon = (to.longitudeInRad - from.longitudeInRad);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return math.atan2(y, x) * 180 / math.pi;
}

double _bearingDelta(double fromDeg, double toDeg) {
  var delta = toDeg - fromDeg;
  while (delta > 180) {
    delta -= 360;
  }
  while (delta < -180) {
    delta += 360;
  }
  return delta;
}