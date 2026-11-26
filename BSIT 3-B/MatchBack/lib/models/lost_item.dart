class LostItem {
  const LostItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.location,
    required this.dateLost,
    required this.privateDetail,
    required this.status,
    this.hasImage = false,
    this.createdAt,
  });

  final String id;
  final String category;
  final String name;
  final String description;
  final String location;
  final String dateLost;

  /// Kept in a separate, protected document. It is NOT part of toJson(),
  /// so it is never written to the public report. Reports loaded from the
  /// database have an empty value here.
  final String privateDetail;

  final String status;
  final bool hasImage;

  /// When the server stored the report. Null for a report just created on
  /// this device, or an old report without the field.
  final DateTime? createdAt;

  /// The public part of the report only.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'description': description,
      'location': location,
      'dateLost': dateLost,
      'status': status,
      'hasImage': hasImage,
    };
  }

  factory LostItem.fromJson(Map<String, dynamic> json) {
    return LostItem(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      dateLost: json['dateLost'] as String,
      privateDetail: '',
      status: json['status'] as String,
      hasImage: (json['hasImage'] as bool?) ?? false,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
    );
  }
}
