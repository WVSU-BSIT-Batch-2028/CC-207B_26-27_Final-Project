import 'package:flutter_test/flutter_test.dart';
import 'package:websupark/data/sample_parking_areas.dart';
import 'package:websupark/models/pass_type.dart';

void main() {
  test('There are 18 areas with unique ids', () {
    expect(sampleParkingAreas.length, 18);
    final ids = sampleParkingAreas.map((a) => a.id).toSet();
    expect(ids.length, sampleParkingAreas.length);
  });

  test('Total capacity matches the guidelines (367 slots)', () {
    final total = sampleParkingAreas.fold<int>(0, (sum, a) => sum + a.capacity);
    expect(total, 367);
  });

  test('P-6 is the CICT area for students and guardians', () {
    final p6 = sampleParkingAreas.firstWhere((a) => a.id == 'P-6');
    expect(p6.capacity, 19);
    expect(p6.allowedPassTypes.contains(PassType.studentWithParking), isTrue);
    expect(p6.allowedPassTypes.contains(PassType.facultyStaffWithParking),
        isFalse);
  });

  test('No area allows the Yellow (no parking privilege) pass', () {
    final anyAllowsYellow = sampleParkingAreas
        .any((a) => a.allowedPassTypes.contains(PassType.withoutParking));
    expect(anyAllowsYellow, isFalse);
  });
}