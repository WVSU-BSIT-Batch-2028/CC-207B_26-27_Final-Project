import '../utils/date_format.dart';

class FoundItem {
  const FoundItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.locationFound,
    required this.dateFound,
    required this.storageLocation,
    required this.status,
    this.hasImage = false,
    this.createdAt,
    this.readyAt,
    this.returnedAt,
  });

  final String id;
  final String category;
  final String name;
  final String description;
  final String locationFound;
  final String dateFound;
  final String storageLocation;
  final String status;
  final bool hasImage;

  /// When the report was stored, when staff marked the item ready for
  /// collection, and when it was physically handed back. The last two are
  /// null until those events happen.
  final DateTime? createdAt;
  final DateTime? readyAt;
  final DateTime? returnedAt;

  FoundItem copyWith({String? status}) {
    return FoundItem(
      id: id,
      category: category,
      name: name,
      description: description,
      locationFound: locationFound,
      dateFound: dateFound,
      storageLocation: storageLocation,
      status: status ?? this.status,
      hasImage: hasImage,
      createdAt: createdAt,
      readyAt: readyAt,
      returnedAt: returnedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'description': description,
      'locationFound': locationFound,
      'dateFound': dateFound,
      'status': status,
      'hasImage': hasImage,
    };
  }

  factory FoundItem.fromJson(Map<String, dynamic> json) {
    return FoundItem(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      locationFound: json['locationFound'] as String,
      dateFound: json['dateFound'] as String,
      // Storage location is kept in found_report_private for new reports.
      // Ignore the field if an older public report still contains it.
      storageLocation: '',
      status: json['status'] as String,
      hasImage: (json['hasImage'] as bool?) ?? false,
      createdAt: parseTime(json['createdAt']),
      readyAt: parseTime(json['readyAt']),
      returnedAt: parseTime(json['returnedAt']),
    );
  }
}
