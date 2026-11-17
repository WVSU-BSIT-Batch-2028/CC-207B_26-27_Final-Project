import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/employee.dart';

Map<String, dynamic> _row({
  String role = 'pharmacist',
  String status = 'verified',
  Object? expiry = '2030-12-31',
  String? middle,
}) {
  return {
    'account_id': 'a1',
    'display_id': 'EMP-000001',
    'role': role,
    'first_name': 'Jose',
    'middle_name': middle,
    'last_name': 'Reyes',
    'prc_license_no': '1234567',
    'prc_license_expiry': expiry,
    'license_status': status,
    'is_active': true,
  };
}

void main() {
  test('reads a staff row', () {
    final e = Employee.fromJson(_row());
    expect(e.displayId, 'EMP-000001');
    expect(e.isPharmacist, true);
    expect(e.isOwner, false);
    expect(e.prcLicenseExpiry, DateTime(2030, 12, 31));
  });

  test('full name skips an empty middle name', () {
    expect(Employee.fromJson(_row()).fullName, 'Jose Reyes');
    expect(Employee.fromJson(_row(middle: 'Dela')).fullName, 'Jose Dela Reyes');
  });

  test('a verified license that has not run out is valid', () {
    final e = Employee.fromJson(_row());
    expect(e.hasValidLicense(DateTime(2026, 11, 17)), true);
  });

  test('a license is still valid on its last day', () {
    final e = Employee.fromJson(_row(expiry: '2026-11-17'));
    expect(e.hasValidLicense(DateTime(2026, 11, 17, 15, 30)), true);
  });

  test('an expired, pending, or missing license is not valid', () {
    final today = DateTime(2026, 11, 17);
    expect(Employee.fromJson(_row(expiry: '2026-11-16')).hasValidLicense(today), false);
    expect(Employee.fromJson(_row(status: 'pending')).hasValidLicense(today), false);
    expect(Employee.fromJson(_row(status: 'none', expiry: null)).hasValidLicense(today), false);
  });
}
