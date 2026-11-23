import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:meditech/services/route_maneuver_instructions.dart';

void main() {
  test('OSRM turn right with road name', () {
    expect(
      osrmManeuverInstruction(
        maneuver: {'type': 'turn', 'modifier': 'right'},
        roadName: 'Magsaysay Avenue',
      ),
      'Turn right onto Magsaysay Avenue',
    );
  });

  test('OSRM slight left', () {
    expect(
      osrmManeuverInstruction(
        maneuver: {'type': 'turn', 'modifier': 'slight left'},
        roadName: '',
      ),
      'Slight left',
    );
  });

  test('polyline fallback uses turn language', () {
    final steps = polylineTurnSteps([
      const LatLng(10.72, 122.56),
      const LatLng(10.72, 122.57),
      const LatLng(10.71, 122.57),
      const LatLng(10.70, 122.55),
    ]);
    expect(steps.length, greaterThan(1));
    expect(
      steps.any((s) => s.instruction.toLowerCase().contains('turn')),
      isTrue,
    );
  });
}