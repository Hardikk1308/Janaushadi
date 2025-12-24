class MasterCategory {
  final String id;
  final String name;
  final String? imageUrl;

  MasterCategory({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  factory MasterCategory.fromJson(Map<String, dynamic> json) {
    return MasterCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Category',
      imageUrl: json['image_url']?.toString(),
    );
  }
}
