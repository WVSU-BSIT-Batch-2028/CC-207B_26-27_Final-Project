import 'package:websupark/models/pass_type.dart';

/// One designated parking area, such as P-6 (CICT).
/// This holds only fixed facts. The number of occupied spaces is NOT stored
/// here: it is calculated from entry/exit records, so it can never
/// contradict them.
class ParkingArea {
  const ParkingArea({
    required this.id,
    required this.name,
    required this.capacity,
    required this.allowedPassTypes,
  }) : assert(capacity >= 0, 'capacity cannot be negative');

  /// Unique code from the guidelines, e.g. 'P-6'.
  final String id;

  /// Location name, e.g. 'CICT'.
  final String name;

  /// Number of four-wheel slots in this area.
  final int capacity;

  /// Pass types that are allowed to park in this area.
  final Set<PassType> allowedPassTypes;
}