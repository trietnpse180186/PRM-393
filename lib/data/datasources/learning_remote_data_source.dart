import '../../core/network/dio_client.dart';
import '../models/course_category_model.dart';
import '../models/course_model.dart';
import '../models/lesson_model.dart';
import '../models/user_lesson_progress_model.dart';
import '../models/enrollment_model.dart';

class LearningRemoteDataSource {
  final DioClient _dioClient;

  LearningRemoteDataSource(this._dioClient);

  Future<List<CourseCategoryModel>> fetchCategories() async {
    try {
      final response = await _dioClient.dio.get('/api/course_categories', queryParameters: {
        'page': 1,
        'pageSize': 100,
      });
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((e) => CourseCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Không thể tải danh mục khóa học.');
    } catch (e) {
      throw Exception('Lỗi tải danh mục: ${e.toString()}');
    }
  }

  Future<List<CourseModel>> fetchCourses() async {
    try {
      final response = await _dioClient.dio.get('/api/courses', queryParameters: {
        'page': 1,
        'pageSize': 100,
      });
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((e) => CourseModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Không thể tải danh sách khóa học.');
    } catch (e) {
      throw Exception('Lỗi tải khóa học: ${e.toString()}');
    }
  }

  Future<List<LessonModel>> fetchLessons() async {
    try {
      final response = await _dioClient.dio.get('/api/lessons', queryParameters: {
        'page': 1,
        'pageSize': 200,
      });
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((e) => LessonModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Không thể tải danh sách bài học.');
    } catch (e) {
      throw Exception('Lỗi tải bài học: ${e.toString()}');
    }
  }

  Future<LessonModel> fetchLessonDetails(int lessonId) async {
    try {
      final response = await _dioClient.dio.get('/api/lessons/$lessonId');
      if (response.statusCode == 200) {
        return LessonModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không thể tải thông tin bài học.');
    } catch (e) {
      throw Exception('Lỗi tải chi tiết bài học: ${e.toString()}');
    }
  }

  Future<List<EnrollmentModel>> fetchUserEnrollments(int userId) async {
    try {
      final response = await _dioClient.dio.get('/api/enrollments/user/$userId');
      if (response.statusCode == 200) {
        final list = response.data as List<dynamic>? ?? [];
        return list.map((e) => EnrollmentModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Không thể tải tiến trình đăng ký học.');
    } catch (e) {
      throw Exception('Lỗi tải danh sách đăng ký: ${e.toString()}');
    }
  }

  Future<List<UserLessonProgressModel>> fetchUserProgress(int userId, int courseId) async {
    try {
      final response = await _dioClient.dio.get('/api/user_lesson_progress/user/$userId/course/$courseId');
      if (response.statusCode == 200) {
        final list = response.data as List<dynamic>? ?? [];
        return list.map((e) => UserLessonProgressModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Không thể tải tiến độ bài học của khóa học.');
    } catch (e) {
      throw Exception('Lỗi tải tiến độ bài học: ${e.toString()}');
    }
  }

  Future<UserLessonProgressModel> upsertLessonProgress({
    required int userId,
    required int lessonId,
    required int status, // 0 = NotStarted, 1 = InProgress, 2 = Completed
    String? startedAt,
    String? completedAt,
    int lastPositionSeconds = 0,
    int attemptsCount = 1,
    double bestAccuracy = 0.0,
    double bestScore = 0.0,
    int totalTimeSeconds = 0,
    int xpEarned = 0,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/user_lesson_progress/upsert',
        data: {
          'userId': userId,
          'lessonId': lessonId,
          'status': status,
          'startedAt': startedAt ?? DateTime.now().toUtc().toIso8601String(),
          'completedAt': completedAt,
          'lastPositionSeconds': lastPositionSeconds,
          'attemptsCount': attemptsCount,
          'bestAccuracy': bestAccuracy,
          'bestScore': bestScore,
          'totalTimeSeconds': totalTimeSeconds,
          'xpEarned': xpEarned,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserLessonProgressModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không thể lưu tiến trình bài học.');
    } catch (e) {
      throw Exception('Lỗi lưu tiến độ: ${e.toString()}');
    }
  }

  Future<EnrollmentModel> enrollInCourse(int userId, int courseId) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/enrollments/enroll',
        data: {
          'userId': userId,
          'courseId': courseId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return EnrollmentModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không thể tham gia khóa học.');
    } catch (e) {
      throw Exception('Lỗi ghi danh khóa học: ${e.toString()}');
    }
  }
}

extension DateTimeExtension on DateTime {
  String toIso8601String() {
    return this.toUtc().toIso8601String();
  }
}
