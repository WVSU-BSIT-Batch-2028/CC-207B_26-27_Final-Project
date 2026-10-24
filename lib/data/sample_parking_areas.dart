import 'package:websupark/models/parking_area.dart';
import 'package:websupark/models/pass_type.dart';

// Reusable groups of pass types, to avoid repeating them 18 times.
const _facultyStaff = {PassType.facultyStaffWithParking};
const _studentsAndGuardians = {
  PassType.studentWithParking,
  PassType.parentGuardianWithParking,
};
const _allWithParking = {
  PassType.studentWithParking,
  PassType.parentGuardianWithParking,
  PassType.facultyStaffWithParking,
};

/// The 18 designated four-wheel parking areas of the main campus.
/// Occupied spaces are NOT stored here; they are calculated later.
const List<ParkingArea> sampleParkingAreas = [
  ParkingArea(
    id: 'P-1',
    name: 'Rehearsal Room / Right Side of Cultural Center',
    capacity: 23,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-2',
    name: 'COC along AV Hall / Left Side of Cultural Center',
    capacity: 22,
    allowedPassTypes: _allWithParking,
  ),
  ParkingArea(
    id: 'P-3',
    name: 'Admin / Unity Park, Lopez Jaena / ULRC',
    capacity: 61, // 54 (Admin) + 7 (Lopez Jaena)
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-4',
    name: 'COM Gym',
    capacity: 25,
    allowedPassTypes: _studentsAndGuardians,
  ),
  ParkingArea(
    id: 'P-5',
    name: 'Rizal Hall',
    capacity: 15,
    allowedPassTypes: _allWithParking,
  ),
  ParkingArea(
    id: 'P-6',
    name: 'CICT',
    capacity: 19,
    allowedPassTypes: _studentsAndGuardians,
  ),
  ParkingArea(
    id: 'P-7',
    name: 'Fronting CICT Lobby',
    capacity: 14,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-8',
    name: 'WVSU MPC',
    capacity: 18,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-9',
    name: 'Road to GSO (emergency use only)',
    capacity: 10,
    allowedPassTypes: <PassType>{},
  ),
  ParkingArea(
    id: 'P-10',
    name: 'R&E',
    capacity: 11,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-11',
    name: 'Roxas Hall',
    capacity: 20,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-12',
    name: 'Roxas Hall Annex',
    capacity: 6,
    allowedPassTypes: _studentsAndGuardians,
  ),
  ParkingArea(
    id: 'P-13',
    name: 'Mini-Forest',
    capacity: 15,
    allowedPassTypes: _studentsAndGuardians,
  ),
  ParkingArea(
    id: 'P-14',
    name: 'Quezon Hall',
    capacity: 19,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-15',
    name: 'HOMETEL',
    capacity: 25,
    allowedPassTypes: _studentsAndGuardians,
  ),
  ParkingArea(
    id: 'P-16',
    name: 'Gabaldon Building',
    capacity: 8,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-17',
    name: 'CBM-CTE',
    capacity: 26,
    allowedPassTypes: _facultyStaff,
  ),
  ParkingArea(
    id: 'P-18',
    name: 'Baseball / Softball Diamond',
    capacity: 30,
    allowedPassTypes: _studentsAndGuardians,
  ),
];