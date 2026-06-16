import '../../../data/models/course_category_model.dart';
import '../../../data/models/course_model.dart';
import '../../../data/models/lesson_model.dart';
import '../../../data/models/user_lesson_progress_model.dart';
import '../../../data/models/enrollment_model.dart';

class LearningState {
  final bool isLoading;
  final String? errorMessage;
  final List<CourseCategoryModel> categories;
  final List<CourseModel> courses;
  final List<EnrollmentModel> enrollments;
  final List<LessonModel> allLessons;
  final List<LessonModel> currentCourseLessons;
  final List<UserLessonProgressModel> currentCourseProgress;
  final LessonModel? activeLesson;

  LearningState({
    this.isLoading = false,
    this.errorMessage,
    this.categories = const [],
    this.courses = const [],
    this.enrollments = const [],
    this.allLessons = const [],
    this.currentCourseLessons = const [],
    this.currentCourseProgress = const [],
    this.activeLesson,
  });

  LearningState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<CourseCategoryModel>? categories,
    List<CourseModel>? courses,
    List<EnrollmentModel>? enrollments,
    List<LessonModel>? allLessons,
    List<LessonModel>? currentCourseLessons,
    List<UserLessonProgressModel>? currentCourseProgress,
    LessonModel? activeLesson,
  }) {
    return LearningState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      categories: categories ?? this.categories,
      courses: courses ?? this.courses,
      enrollments: enrollments ?? this.enrollments,
      allLessons: allLessons ?? this.allLessons,
      currentCourseLessons: currentCourseLessons ?? this.currentCourseLessons,
      currentCourseProgress: currentCourseProgress ?? this.currentCourseProgress,
      activeLesson: activeLesson ?? this.activeLesson,
    );
  }
}
