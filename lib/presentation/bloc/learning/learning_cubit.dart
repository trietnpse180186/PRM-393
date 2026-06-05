import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/learning_remote_data_source.dart';
import 'learning_state.dart';

class LearningCubit extends Cubit<LearningState> {
  final LearningRemoteDataSource _dataSource;

  LearningCubit(this._dataSource) : super(LearningState());

  Future<void> loadCatalog(int userId) async {
    emit(state.copyWith(isLoading: true));
    try {
      final categories = await _dataSource.fetchCategories();
      final courses = await _dataSource.fetchCourses();
      final enrollments = await _dataSource.fetchUserEnrollments(userId);
      final allLessons = await _dataSource.fetchLessons();

      emit(state.copyWith(
        isLoading: false,
        categories: categories,
        courses: courses,
        enrollments: enrollments,
        allLessons: allLessons,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadCourseDetails(int userId, int courseId) async {
    emit(state.copyWith(isLoading: true));
    try {
      // Fetch all lessons and filter by courseId
      final allLessons = await _dataSource.fetchLessons();
      print("learning_cubit: Loaded ${allLessons.length} lessons from API.");
      for (final l in allLessons) {
        print("learning_cubit: Lesson ID: ${l.id}, Title: ${l.title}, CourseId: ${l.courseId}");
      }
      
      final courseLessons = allLessons.where((l) => l.courseId == courseId).toList();
      print("learning_cubit: Filtered ${courseLessons.length} lessons for Course ID $courseId: ${courseLessons.map((l) => l.title).toList()}");
      
      // Sort lessons by sortOrder
      courseLessons.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // Fetch progress
      final progress = await _dataSource.fetchUserProgress(userId, courseId);

      emit(state.copyWith(
        isLoading: false,
        currentCourseLessons: courseLessons,
        currentCourseProgress: progress,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadLessonDetails(int lessonId) async {
    emit(state.copyWith(isLoading: true));
    try {
      final lessonDetails = await _dataSource.fetchLessonDetails(lessonId);
      emit(state.copyWith(
        isLoading: false,
        activeLesson: lessonDetails,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> startLesson(int userId, int lessonId) async {
    try {
      await _dataSource.upsertLessonProgress(
        userId: userId,
        lessonId: lessonId,
        status: 1, // InProgress
      );
    } catch (e) {
      // Fail silently in background
    }
  }

  Future<void> completeLesson({
    required int userId,
    required int lessonId,
    required int courseId,
    double accuracy = 0.0,
    double score = 0.0,
    int xpEarned = 50,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _dataSource.upsertLessonProgress(
        userId: userId,
        lessonId: lessonId,
        status: 2, // Completed
        completedAt: DateTime.now().toUtc().toIso8601String(),
        bestAccuracy: accuracy,
        bestScore: score,
        xpEarned: xpEarned,
      );

      // Refresh enrollments, catalog, and progress
      final enrollments = await _dataSource.fetchUserEnrollments(userId);
      final progress = await _dataSource.fetchUserProgress(userId, courseId);

      emit(state.copyWith(
        isLoading: false,
        enrollments: enrollments,
        currentCourseProgress: progress,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> enrollInCourse(int userId, int courseId) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _dataSource.enrollInCourse(userId, courseId);
      final enrollments = await _dataSource.fetchUserEnrollments(userId);
      
      emit(state.copyWith(
        isLoading: false,
        enrollments: enrollments,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
