import 'package:flutter_test/flutter_test.dart';
import 'package:websupark/models/parking_area.dart';
import 'package:websupark/models/pass_type.dart';

void main() {
  test('Only the Yellow pass has no parking privilege', () {
    expect(PassType.studentWithParking.hasParkingPrivilege, isTrue);
    expect(PassType.withoutParking.hasParkingPrivilege, isFalse);
  });

  test('ParkingArea keeps the values it was created with', () {
    const area = ParkingArea(
      id: 'P-6',
      name: 'CICT',
      capacity: 19,
      allowedPassTypes: {PassType.studentWithParking},
    );

    expect(area.id, 'P-6');
    expect(area.capacity, 19);
    expect(area.allowedPassTypes.contains(PassType.withoutParking), isFalse);
  });
}