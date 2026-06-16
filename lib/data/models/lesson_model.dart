class LessonModel {
  final int id;
  final int courseId;
  final int moduleId;
  final String title;
  final String slug;
  final String? shortDescription;
  final String? objectiveText;
  final int? coverMediaId;
  final int? videoMediaId;
  final String? videoUrl;
  final String lessonType;
  final String difficultyLevel;
  final int estimatedMinutes;
  final int xpReward;
  final int sortOrder;

  LessonModel({
    required this.id,
    required this.courseId,
    required this.moduleId,
    required this.title,
    required this.slug,
    this.shortDescription,
    this.objectiveText,
    this.coverMediaId,
    this.videoMediaId,
    this.videoUrl,
    required this.lessonType,
    required this.difficultyLevel,
    required this.estimatedMinutes,
    required this.xpReward,
    required this.sortOrder,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as int? ?? json['Id'] as int? ?? 0,
      courseId: json['courseId'] as int? ?? json['CourseId'] as int? ?? 0,
      moduleId: json['moduleId'] as int? ?? json['ModuleId'] as int? ?? 0,
      title: json['title'] as String? ?? json['Title'] as String? ?? '',
      slug: json['slug'] as String? ?? json['Slug'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? json['ShortDescription'] as String?,
      objectiveText: json['objectiveText'] as String? ?? json['ObjectiveText'] as String?,
      coverMediaId: json['coverMediaId'] as int? ?? json['CoverMediaId'] as int?,
      videoMediaId: json['videoMediaId'] as int? ?? json['VideoMediaId'] as int?,
      videoUrl: json['videoUrl'] as String? ?? json['VideoUrl'] as String?,
      lessonType: json['lessonType'] as String? ?? json['LessonType'] as String? ?? 'Video',
      difficultyLevel: json['difficultyLevel'] as String? ?? json['DifficultyLevel'] as String? ?? 'Beginner',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? json['EstimatedMinutes'] as int? ?? 0,
      xpReward: json['xpReward'] as int? ?? json['XpReward'] as int? ?? 0,
      sortOrder: json['sortOrder'] as int? ?? json['SortOrder'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'moduleId': moduleId,
      'title': title,
      'slug': slug,
      'shortDescription': shortDescription,
      'objectiveText': objectiveText,
      'coverMediaId': coverMediaId,
      'videoMediaId': videoMediaId,
      'videoUrl': videoUrl,
      'lessonType': lessonType,
      'difficultyLevel': difficultyLevel,
      'estimatedMinutes': estimatedMinutes,
      'xpReward': xpReward,
      'sortOrder': sortOrder,
    };
  }
}
