class Product {
  final String id;
  final String name;
  final String brand;
  final double originalPrice;
  final double salePrice;
  final double rating;
  final int discountPercent;
  final String imageUrl;
  final List<String> imageUrls; // Multiple images
  final String description;
  final String composition;
  final String hsn_code;
  final String unit;
  final String description1;
  final String description2;
  final String description3;
  final String description4;
  final String description5;
  final String description6;
  final String description7;
  final String catId;
  final String catName;
  final String subcatId;
  final String subcatName;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.originalPrice,
    required this.salePrice,
    required this.rating,
    required this.discountPercent,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.description,
    required this.composition,
    required this.hsn_code,
    required this.unit,
    required this.description1,
    required this.description2,
    required this.description3,
    required this.description4,
    required this.description5,
    required this.description6,
    required this.description7,
    this.catId = '',
    this.catName = '',
    this.subcatId = '',
    this.subcatName = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    String imageFilename = '';
    List<String> allImages = [];
    
    if (json['image'] is Map && (json['image'] as Map).isNotEmpty) {
      final imageMap = json['image'] as Map<String, dynamic>;
      // Get all image values from the map in order, preserving all images
      for (var value in imageMap.values) {
        if (value != null && value.toString().isNotEmpty) {
          allImages.add(value.toString());
        }
      }
      imageFilename = allImages.isNotEmpty ? allImages.first : '';
    } else if (json['product_image'] != null) {
      imageFilename = json['product_image'].toString();
      if (imageFilename.isNotEmpty) {
        allImages = [imageFilename];
      }
    }

    return Product(
      id: json['product_id']?.toString() ?? '',
      name: json['product_name']?.toString() ?? 'Unknown',
      brand: json['brand_name']?.toString() ?? 'Generic',
      originalPrice: double.tryParse(json['mrp']?.toString() ?? '0') ?? 0.0,
      salePrice: double.tryParse(json['sale_price']?.toString() ?? '0') ?? 0.0,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      discountPercent:
          int.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0,
      imageUrl: imageFilename,
      imageUrls: allImages,
      description: json['description']?.toString() ?? '',
      composition: json['composition']?.toString() ?? '',
      hsn_code: json['hsn_code']?.toString() ?? '',
      unit: json['unit_name']?.toString() ?? '',
      description1: json['description1']?.toString() ?? '',
      description2: json['description2']?.toString() ?? '',
      description3: json['description3']?.toString() ?? '',
      description4: json['description4']?.toString() ?? '',
      description5: json['description5']?.toString() ?? '',
      description6: json['description6']?.toString() ?? '',
      description7: json['description7']?.toString() ?? '',
      catId: json['cat_id']?.toString() ?? '',
      catName: json['cat_name']?.toString() ?? '',
      subcatId: json['subcat_id']?.toString() ?? '',
      subcatName: json['subcat_name']?.toString() ?? '',
    );
  }
}