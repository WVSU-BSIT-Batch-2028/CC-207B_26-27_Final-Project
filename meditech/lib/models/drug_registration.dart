// An official FDA drug registration
class DrugRegistration {
  const DrugRegistration({
    required this.id,
    required this.registrationNumber,
    required this.genericName,
    this.brandName,
    required this.strength,
    required this.dosageFormId,
    this.manufacturer,
    required this.isRx,
  });

  final String id;
  final String registrationNumber;
  final String genericName;
  final String? brandName;
  final String strength;
  final int dosageFormId;
  final String? manufacturer;
  final bool isRx;

  factory DrugRegistration.fromJson(Map<String, dynamic> json) => DrugRegistration(
        id: json['id'] as String,
        registrationNumber: json['registration_number'] as String,
        genericName: json['generic_name'] as String,
        brandName: json['brand_name'] as String?,
        strength: json['strength'] as String,
        dosageFormId: json['dosage_form_id'] as int,
        manufacturer: json['manufacturer'] as String?,
        isRx: json['is_rx'] as bool,
      );
}

// An item from a short list, like a dosage form or a selling unit
class LookupItem {
  const LookupItem({required this.id, required this.name});

  final int id;
  final String name;

  factory LookupItem.fromJson(Map<String, dynamic> json) =>
      LookupItem(id: json['id'] as int, name: json['name'] as String);
}