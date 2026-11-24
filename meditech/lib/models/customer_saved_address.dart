class CustomerSavedAddress {
  const CustomerSavedAddress({
    required this.id,
    required this.label,
    required this.line1,
    this.line2,
    this.city,
    this.province,
    this.postalCode,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String line1;
  final String? line2;
  final String? city;
  final String? province;
  final String? postalCode;
  final bool isDefault;

  String get singleLine {
    final parts = <String>[
      line1,
      if (line2 != null && line2!.isNotEmpty) line2!,
      if (city != null && city!.isNotEmpty) city!,
      if (province != null && province!.isNotEmpty) province!,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode!,
    ];
    return parts.join(', ');
  }

  factory CustomerSavedAddress.fromJson(Map<String, dynamic> json) {
    return CustomerSavedAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      postalCode: json['postal_code'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'label': label,
      'line1': line1,
      'line2': line2,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'is_default': isDefault,
    };
  }

  Map<String, dynamic> toUpdateJson() => toInsertJson();
}