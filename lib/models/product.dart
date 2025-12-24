class Product {
  final String id;
  final String name;
  final String brand;
  final double salePrice;
  final double originalPrice;
  final String imageUrl;
  final double rating;
  final double discountPercent;

  // Description fields as per your requirements
  final String description1; // short description
  final String description2; // product Information
  final String description3; // Key Uses
  final String description4; // Safety information
  final String description5; // Side Effect
  final String description6; // How To Use
  final String description7; // Additional Information

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.salePrice,
    required this.originalPrice,
    required this.imageUrl,
    required this.rating,
    required this.discountPercent,
    this.description1 = '',
    this.description2 = '',
    this.description3 = '',
    this.description4 = '',
    this.description5 = '',
    this.description6 = '',
    this.description7 = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      salePrice: _parseDouble(json['sale_price']),
      originalPrice: _parseDouble(json['original_price'] ?? json['price']),
      imageUrl:
          json['image']?.toString() ?? json['image_url']?.toString() ?? '',
      rating: _parseDouble(json['rating']),
      discountPercent: _parseDouble(
        json['discount_percent'] ?? json['discount'],
      ),
      description1:
          json['description1']?.toString() ??
          json['short_description']?.toString() ??
          '',
      description2:
          json['description2']?.toString() ??
          json['product_information']?.toString() ??
          '',
      description3:
          json['description3']?.toString() ??
          json['key_uses']?.toString() ??
          '',
      description4:
          json['description4']?.toString() ??
          json['safety_information']?.toString() ??
          '',
      description5:
          json['description5']?.toString() ??
          json['side_effect']?.toString() ??
          '',
      description6:
          json['description6']?.toString() ??
          json['how_to_use']?.toString() ??
          '',
      description7:
          json['description7']?.toString() ??
          json['additional_information']?.toString() ??
          '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'sale_price': salePrice,
      'original_price': originalPrice,
      'image': imageUrl,
      'rating': rating,
      'discount_percent': discountPercent,
      'description1': description1,
      'description2': description2,
      'description3': description3,
      'description4': description4,
      'description5': description5,
      'description6': description6,
      'description7': description7,
    };
  }
}
