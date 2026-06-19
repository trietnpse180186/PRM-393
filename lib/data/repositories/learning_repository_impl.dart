import '../../domain/entities/course_category_entity.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/enrollment_entity.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/user_lesson_progress_entity.dart';
import '../../domain/repositories/learning_repository.dart';
import '../datasources/learning_remote_data_source.dart';

class LearningRepositoryImpl implements LearningRepository {
  final LearningRemoteDataSource remoteDataSource;

  LearningRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<CourseCategoryEntity>> fetchCategories() {
    return remoteDataSource.fetchCategories();
  }

  @override
  Future<List<CourseEntity>> fetchCourses() {
    return remoteDataSource.fetchCourses();
  }

  @override
  Future<List<LessonEntity>> fetchLessons() {
    return remoteDataSource.fetchLessons();
  }

  @override
  Future<LessonEntity> fetchLessonDetails(int lessonId) {
    return remoteDataSource.fetchLessonDetails(lessonId);
  }

  @override
  Future<List<EnrollmentEntity>> fetchUserEnrollments(int userId) {
    return remoteDataSource.fetchUserEnrollments(userId);
  }

  @override
  Future<List<UserLessonProgressEntity>> fetchUserProgress(int userId, int courseId) {
    return remoteDataSource.fetchUserProgress(userId, courseId);
  }

  @override
  Future<UserLessonProgressEntity> upsertLessonProgress({
    required int userId,
    required int lessonId,
    required int status,
    String? startedAt,
    String? completedAt,
    int lastPositionSeconds = 0,
    int attemptsCount = 1,
    double bestAccuracy = 0.0,
    double bestScore = 0.0,
    int totalTimeSeconds = 0,
    int xpEarned = 0,
  }) {
    return remoteDataSource.upsertLessonProgress(
      userId: userId,
      lessonId: lessonId,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      lastPositionSeconds: lastPositionSeconds,
      attemptsCount: attemptsCount,
      bestAccuracy: bestAccuracy,
      bestScore: bestScore,
      totalTimeSeconds: totalTimeSeconds,
      xpEarned: xpEarned,
    );
  }

  @override
  Future<EnrollmentEntity> enrollInCourse(int userId, int courseId) {
    return remoteDataSource.enrollInCourse(userId, courseId);
  }

  @override
  Future<String?> fetchVideoUrl(int mediaId) {
    return remoteDataSource.fetchVideoUrl(mediaId);
  }

  @override
  Future<int> fetchUserStreak(int userId) {
    return remoteDataSource.fetchUserStreak(userId);
  }

  @override
  Future<int> fetchTotalCompletedWords(int userId) {
    return remoteDataSource.fetchTotalCompletedWords(userId);
  }

  @override
  Future<void> updateUserStreak(int userId, int newStreak) {
    return remoteDataSource.updateUserStreak(userId, newStreak);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCompletedLessonsWithProgress(int userId) {
    return remoteDataSource.fetchCompletedLessonsWithProgress(userId);
  }
}
