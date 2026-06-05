class CourseModel {
  final int id;
  final int categoryId;
  final String title;
  final String slug;
  final String? summary;
  final String? description;
  final String level;
  final int? coverMediaId;
  final int? trailerMediaId;
  final bool isPremium;
  final String status;

  CourseModel({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.slug,
    this.summary,
    this.description,
    required this.level,
    this.coverMediaId,
    this.trailerMediaId,
    required this.isPremium,
    required this.status,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    // Backend might return status as int (e.g. 1) or string (e.g. "Published")
    final rawStatus = json['status'] ?? json['Status'];
    String statusStr = 'Draft';
    if (rawStatus is int) {
      statusStr = rawStatus == 1 ? 'Published' : 'Draft';
    } else if (rawStatus is String) {
      statusStr = rawStatus;
    }

    return CourseModel(
      id: json['id'] as int? ?? json['Id'] as int? ?? 0,
      categoryId: json['categoryId'] as int? ?? json['CategoryId'] as int? ?? 0,
      title: json['title'] as String? ?? json['Title'] as String? ?? '',
      slug: json['slug'] as String? ?? json['Slug'] as String? ?? '',
      summary: json['summary'] as String? ?? json['Summary'] as String?,
      description: json['description'] as String? ?? json['Description'] as String?,
      level: json['level'] as String? ?? json['Level'] as String? ?? 'Cơ bản',
      coverMediaId: json['coverMediaId'] as int? ?? json['CoverMediaId'] as int?,
      trailerMediaId: json['trailerMediaId'] as int? ?? json['TrailerMediaId'] as int?,
      isPremium: json['isPremium'] as bool? ?? json['IsPremium'] as bool? ?? false,
      status: statusStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'title': title,
      'slug': slug,
      'summary': summary,
      'description': description,
      'level': level,
      'coverMediaId': coverMediaId,
      'trailerMediaId': trailerMediaId,
      'isPremium': isPremium,
      'status': status,
    };
  }
}
