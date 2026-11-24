class Food {
  final int id;
  final String documentId;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final double? caloriesKcal;
  final String? nutritionSource;
  final String? imageUrl;
  final String categoryName;
  final String businessName;
  final String businessAddress;

  Food({
    required this.id,
    required this.documentId,
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    this.caloriesKcal,
    this.nutritionSource,
    this.imageUrl,
    required this.categoryName,
    required this.businessName,
    required this.businessAddress,
  });

  factory Food.fromJson(Map<String, dynamic> json, String baseUrl) {
    final image = json['image'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;
    final business = json['business'] as Map<String, dynamic>?;

    final imagePath = image?['url'] as String?;

    return Food(
      id: json['id'] as int,
      documentId: json['documentId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Food',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isAvailable: json['isAvailable'] == true,
      caloriesKcal: (json['caloriesKcal'] as num?)?.toDouble(),
      nutritionSource: json['nutritionSource']?.toString(),
      imageUrl: imagePath == null
          ? null
          : Uri.parse(baseUrl).resolve(imagePath).toString(),
      categoryName: category?['name']?.toString() ?? 'Uncategorized',
      businessName: business?['name']?.toString() ?? 'Unknown Business',
      businessAddress: business?['address']?.toString() ?? '',
    );
  }
}
