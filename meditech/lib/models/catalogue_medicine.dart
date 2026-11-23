// One row in the admin catalogue table
class CatalogueMedicine {
  const CatalogueMedicine({
    required this.id,
    required this.displayId,
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.unitSold,
    this.packDescription,
    required this.isRx,
    required this.status,
    this.registrationId,
    this.registrationNumber,
    required this.fdaMatched,
    required this.pharmaciesStocking,
    this.imagePath,
  });

  final String id;
  final String displayId; // like MED-000016
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unitSold;
  final String? packDescription;
  final bool isRx;
  final String status; // draft, active, inactive
  final String? registrationId;
  final String? registrationNumber;
  final bool fdaMatched;
  final int pharmaciesStocking;
  final String? imagePath;

  factory CatalogueMedicine.fromJson(Map<String, dynamic> json) => CatalogueMedicine(
        id: json['id'] as String,
        displayId: json['display_id'] as String,
        brandName: json['brand_name'] as String,
        genericName: json['generic_name'] as String,
        strength: json['strength'] as String,
        dosageForm: json['dosage_form'] as String,
        unitSold: json['unit_sold'] as String,
        packDescription: json['pack_description'] as String?,
        isRx: json['is_rx'] as bool,
        status: json['status'] as String,
        registrationId: json['registration_id'] as String?,
        registrationNumber: json['registration_number'] as String?,
        fdaMatched: json['fda_matched'] as bool? ?? false,
        pharmaciesStocking: (json['pharmacies_stocking'] as num).toInt(),
        imagePath: json['image_path'] as String?,
      );
}