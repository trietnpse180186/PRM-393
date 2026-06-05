class CourseCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? colorHex;
  final int? iconMediaId;

  CourseCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.colorHex,
    this.iconMediaId,
  });

  factory CourseCategoryModel.fromJson(Map<String, dynamic> json) {
    return CourseCategoryModel(
      id: json['id'] as int? ?? json['Id'] as int? ?? 0,
      name: json['name'] as String? ?? json['Name'] as String? ?? '',
      slug: json['slug'] as String? ?? json['Slug'] as String? ?? '',
      description: json['description'] as String? ?? json['Description'] as String?,
      colorHex: json['colorHex'] as String? ?? json['ColorHex'] as String?,
      iconMediaId: json['iconMediaId'] as int? ?? json['IconMediaId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'colorHex': colorHex,
      'iconMediaId': iconMediaId,
    };
  }
}
