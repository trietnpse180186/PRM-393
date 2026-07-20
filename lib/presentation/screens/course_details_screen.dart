import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/course_model.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/user_lesson_progress_entity.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/learning/learning_cubit.dart';
import '../bloc/learning/learning_state.dart';
import '../widgets/course_cover_image.dart';
import 'lesson_screen.dart';

class CourseDetailsScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CourseDetailsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  int _userId = 3; // Default test user
  int _userRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _isLessonsExpanded = true; // Quản lý việc đóng/mở danh sách bài học

  // Review System States
  List<dynamic> _allReviews = [];
  List<dynamic> _filteredReviews = [];
  String _activeFilter = 'all';
  bool _isLoadingReviews = true;

  int _countAll = 0;
  int _count5 = 0;
  int _count4 = 0;
  int _count3 = 0;
  int _count2 = 0;
  int _count1 = 0;
  int _countComment = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        setState(() {
          _userId = authState.user.id;
        });
      }
      _loadData();
    });
  }

  void _loadData() {
    context.read<LearningCubit>().loadCourseDetails(_userId, widget.courseId);
    _loadReviews();
    
    // Auto-enroll if not already enrolled
    final state = context.read<LearningCubit>().state;
    final isEnrolled = state.enrollments.any((e) => e.courseId == widget.courseId);
    if (!isEnrolled) {
      context.read<LearningCubit>().enrollInCourse(_userId, widget.courseId);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final dio = DioClient().dio;
      final response = await dio.get('/api/feedbacks?pageSize=1000');
      if (response.statusCode == 200) {
        final raw = response.data;
        List<dynamic> items = [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          items = (raw['items'] ?? raw['Items'] ?? raw['data'] ?? []) as List<dynamic>;
        }

        final filtered = items.where((item) {
          final subj = (item['subject'] ?? item['Subject'] ?? '').toString();
          return subj == 'CourseId:${widget.courseId}';
        }).toList();

        if (mounted) {
          setState(() {
            _allReviews = filtered;
            _calculateStats();
            _applyFilter();
            _isLoadingReviews = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  void _calculateStats() {
    _countAll = _allReviews.length;
    _count5 = _allReviews.where((r) => (r['rating'] ?? r['Rating']) == 5).length;
    _count4 = _allReviews.where((r) => (r['rating'] ?? r['Rating']) == 4).length;
    _count3 = _allReviews.where((r) => (r['rating'] ?? r['Rating']) == 3).length;
    _count2 = _allReviews.where((r) => (r['rating'] ?? r['Rating']) == 2).length;
    _count1 = _allReviews.where((r) => (r['rating'] ?? r['Rating']) == 1).length;
    _countComment = _allReviews.where((r) {
      final content = r['content'] ?? r['Content'];
      return content != null && content.toString().trim().isNotEmpty;
    }).length;
  }

  void _applyFilter() {
    if (_activeFilter == 'all') {
      _filteredReviews = _allReviews;
    } else if (_activeFilter == 'comment') {
      _filteredReviews = _allReviews.where((r) {
        final content = r['content'] ?? r['Content'];
        return content != null && content.toString().trim().isNotEmpty;
      }).toList();
    } else {
      final ratingNum = int.tryParse(_activeFilter) ?? 5;
      _filteredReviews = _allReviews.where((r) => (r['rating'] ?? r['Rating']) == ratingNum).toList();
    }
  }

  Widget _buildReviewFilterTag(String label, String filterKey) {
    final bool isActive = _activeFilter == filterKey;
    const Color mintColor = Color(0xFF10B981);
    return InkWell(
      onTap: () {
        setState(() {
          _activeFilter = filterKey;
          _applyFilter();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? mintColor : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? mintColor : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.courseTitle,
          style: textTheme.headlineSmall?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.onSurfaceVariant),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.surfaceContainerHighest,
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            height: 1.0,
          ),
        ),
      ),
      body: BlocBuilder<LearningCubit, LearningState>(
        builder: (context, state) {
          if (state.isLoading && state.currentCourseLessons.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            );
          }

          if (state.errorMessage != null && state.currentCourseLessons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lỗi tải chi tiết khóa học: ${state.errorMessage}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Find specific course details if stored in state.courses
          final course = state.courses.firstWhere(
            (c) => c.id == widget.courseId,
            orElse: () => CourseModel(
              id: widget.courseId,
              categoryId: 0,
              title: widget.courseTitle,
              slug: '',
              summary: 'Khóa học nền tảng ngôn ngữ ký hiệu',
              description: 'Khóa học giúp bạn làm quen với các ký hiệu cử chỉ tay và biểu cảm khuôn mặt.',
              level: 'Cơ bản',
              isPremium: false,
              status: 'Published',
            ),
          );


          // Calculate local progress dynamically based on course lessons status to ensure instant updates
          final totalLessons = state.currentCourseLessons.length;
          final completedLessonsCount = state.currentCourseLessons.where((l) {
            final lessonProgress = state.currentCourseProgress.firstWhere(
              (p) => p.lessonId == l.id,
              orElse: () => UserLessonProgressEntity(
                id: 0,
                userId: _userId,
                lessonId: l.id,
                status: 0,
                lastPositionSeconds: 0,
                attemptsCount: 0,
                bestAccuracy: 0.0,
                bestScore: 0.0,
                totalTimeSeconds: 0,
                xpEarned: 0,
              ),
            );
            return lessonProgress.status == 2;
          }).length;
          
          final calculatedProgressPercent = totalLessons > 0 
              ? (completedLessonsCount / totalLessons) * 100.0 
              : 0.0;
          final progressFraction = calculatedProgressPercent / 100.0;

          // Find first uncompleted lesson
          LessonEntity? nextLesson;
          for (int i = 0; i < state.currentCourseLessons.length; i++) {
            final lesson = state.currentCourseLessons[i];
            final prog = state.currentCourseProgress.firstWhere(
              (p) => p.lessonId == lesson.id,
              orElse: () => UserLessonProgressEntity(
                id: 0,
                userId: _userId,
                lessonId: lesson.id,
                status: 0,
                lastPositionSeconds: 0,
                attemptsCount: 0,
                bestAccuracy: 0.0,
                bestScore: 0.0,
                totalTimeSeconds: 0,
                xpEarned: 0,
              ),
            );
            if (prog.status != 2) {
              nextLesson = lesson;
              break;
            }
          }
          if (nextLesson == null && state.currentCourseLessons.isNotEmpty) {
            nextLesson = state.currentCourseLessons.first;
          }

          String buttonText = 'Bắt đầu học';
          if (calculatedProgressPercent > 0.0 && calculatedProgressPercent < 100.0) {
            buttonText = 'Tiếp tục học';
          } else if (calculatedProgressPercent >= 100.0) {
            buttonText = 'Học lại';
          }

          return Stack(
            children: [
              Container(color: AppTheme.backgroundColor),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        color: AppTheme.primaryColor,
                        backgroundColor: AppTheme.surfaceContainer,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Hero Banner: Course Promo Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CourseCoverImage(
                                          coverMediaId: course.coverMediaId,
                                          fit: BoxFit.cover,
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 16,
                                          left: 16,
                                          right: 16,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                                      ),
                                                      child: Text(
                                                        'VSL ${course.level.toUpperCase()}',
                                                        style: textTheme.labelLarge?.copyWith(
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.primaryColor,
                                                          letterSpacing: 1.0,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      widget.courseTitle,
                                                      style: textTheme.headlineSmall?.copyWith(
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.5),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.star_rounded, color: AppTheme.primaryColor, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '4.9',
                                                      style: textTheme.labelLarge?.copyWith(
                                                        fontSize: 12,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Progress Overview Panel
                                AppTheme.glassPanel(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tiến độ hoàn thành',
                                            style: textTheme.bodyMedium?.copyWith(
                                              fontSize: 13,
                                              color: AppTheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '${calculatedProgressPercent.toInt()}% ',
                                                  style: textTheme.headlineMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: 'của khóa học',
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    fontSize: 13,
                                                    color: AppTheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: CircularProgressIndicator(
                                              value: progressFraction,
                                              strokeWidth: 4,
                                              backgroundColor: Colors.white.withOpacity(0.05),
                                              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                                            ),
                                          ),
                                          const Icon(Icons.auto_graph_rounded, color: AppTheme.primaryColor, size: 18),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Lessons List Expandable Container
                                AppTheme.glassPanel(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isLessonsExpanded = !_isLessonsExpanded;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 20),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Nội dung bài học',
                                                    style: textTheme.headlineSmall?.copyWith(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${state.currentCourseLessons.length} Bài học',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppTheme.primaryColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    _isLessonsExpanded
                                                        ? Icons.keyboard_arrow_up_rounded
                                                        : Icons.keyboard_arrow_down_rounded,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Expandable Lessons Content
                                      if (_isLessonsExpanded) ...[
                                        const SizedBox(height: 16),
                                        if (state.currentCourseLessons.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 24.0),
                                            child: Text(
                                              'Chưa có bài học nào trong khóa học này.',
                                              style: TextStyle(color: AppTheme.onSurfaceVariant),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        else
                                          ...List.generate(state.currentCourseLessons.length, (index) {
                                            final lesson = state.currentCourseLessons[index];
                                            
                                            // Logic for locked lessons:
                                            bool isLocked = false;
                                            if (index > 0) {
                                              final prevLesson = state.currentCourseLessons[index - 1];
                                              final prevProg = state.currentCourseProgress.firstWhere(
                                                (p) => p.lessonId == prevLesson.id,
                                                orElse: () => UserLessonProgressEntity(
                                                  id: 0,
                                                  userId: _userId,
                                                  lessonId: prevLesson.id,
                                                  status: 0,
                                                  lastPositionSeconds: 0,
                                                  attemptsCount: 0,
                                                  bestAccuracy: 0.0,
                                                  bestScore: 0.0,
                                                  totalTimeSeconds: 0,
                                                  xpEarned: 0,
                                                ),
                                              );
                                              isLocked = prevProg.status != 2;
                                            }

                                            // Get current lesson progress
                                            final lessonProgress = state.currentCourseProgress.firstWhere(
                                              (p) => p.lessonId == lesson.id,
                                              orElse: () => UserLessonProgressEntity(
                                                id: 0,
                                                userId: _userId,
                                                lessonId: lesson.id,
                                                status: 0,
                                                lastPositionSeconds: 0,
                                                attemptsCount: 0,
                                                bestAccuracy: 0.0,
                                                bestScore: 0.0,
                                                totalTimeSeconds: 0,
                                                xpEarned: 0,
                                              ),
                                            );

                                            // Status mapping: completed, in_progress, locked, not_started
                                            String statusStr = 'not_started';
                                            if (isLocked) {
                                              statusStr = 'locked';
                                            } else if (lessonProgress.status == 2) {
                                              statusStr = 'completed';
                                            } else if (lessonProgress.status == 1) {
                                              statusStr = 'in_progress';
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12.0),
                                              child: _buildLessonCard(context, lesson, statusStr, textTheme, index),
                                            );
                                          }),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // About course section
                                AppTheme.glassPanel(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Về khóa học này',
                                        style: textTheme.headlineSmall?.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        course.description ?? course.summary ?? 'Chưa có thông tin giới thiệu.',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.onSurfaceVariant,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildCourseChip('Cấp độ: ${course.level}', textTheme),
                                          _buildCourseChip('Tiếng Việt', textTheme),
                                          _buildCourseChip('Bài tập thực hành AI', textTheme),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildReviewSection(textTheme),
                                const SizedBox(height: 64), // Buffer spacing for floating button
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Floating Action Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.backgroundColor.withOpacity(0.0),
                            AppTheme.backgroundColor.withOpacity(0.9),
                            AppTheme.backgroundColor,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: nextLesson == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LessonScreen(lesson: nextLesson!),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryContainer,
                          foregroundColor: AppTheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.primaryContainer.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_filled_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              buttonText,
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCourseChip(String label, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(
          fontSize: 11,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, LessonEntity lesson, String status, TextTheme textTheme, int index) {
    final isLocked = status == 'locked';
    const Color mintColor = Color(0xFF10B981);
    const Color darkCardColor = Color(0xFF131A16);

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bài học này hiện đang bị khóa. Hãy hoàn thành các bài học trước!'),
              backgroundColor: AppTheme.surfaceContainer,
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonScreen(lesson: lesson),
            ),
          );
        }
      },
      child: Opacity(
        opacity: isLocked ? 0.7 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: darkCardColor,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Left status circle/index
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isLocked 
                      ? Colors.white.withOpacity(0.04) 
                      : (status == 'completed' 
                          ? mintColor.withOpacity(0.15) 
                          : mintColor.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLocked
                      ? const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 15)
                      : (status == 'completed'
                          ? const Icon(Icons.check_rounded, color: mintColor, size: 16)
                          : Text(
                              "${index + 1}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: mintColor,
                                fontSize: 13,
                              ),
                            )),
                ),
              ),
              const SizedBox(width: 16),
              
              // Middle title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked 
                          ? "Bài học đã bị khóa" 
                          : "Thời lượng: ${lesson.estimatedMinutes} phút • +${lesson.xpReward} XP",
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Right Action Icon
              Icon(
                isLocked 
                    ? Icons.lock_outline_rounded 
                    : (status == 'completed' 
                        ? Icons.check_circle_rounded 
                        : Icons.play_circle_fill_rounded),
                color: isLocked 
                    ? const Color(0xFF94A3B8).withOpacity(0.5) 
                    : mintColor,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection(TextTheme textTheme) {
    const Color mintColor = Color(0xFF10B981);

    return AppTheme.glassPanel(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Write Review Section (ON TOP)
          Text(
            'Viết đánh giá của bạn',
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Star rating selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                icon: Icon(
                  starValue <= _userRating 
                      ? Icons.star_rounded 
                      : Icons.star_border_rounded,
                  color: const Color(0xFFFFD700),
                  size: 32,
                ),
                onPressed: _isSubmittingReview 
                    ? null 
                    : () {
                        setState(() {
                          _userRating = starValue;
                        });
                      },
              );
            }),
          ),
          const SizedBox(height: 8),
          // Comment TextField
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 200,
            enabled: !_isSubmittingReview,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nhập ý kiến đóng góp của bạn về khóa học...',
              hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Submit Button
          ElevatedButton(
            onPressed: _isSubmittingReview ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: mintColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmittingReview
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'Gửi đánh giá',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // 2. Display Reviews List Section (BELOW)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đánh giá & Nhận xét (${_allReviews.length})',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_allReviews.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${(_allReviews.fold<double>(0.0, (acc, curr) => acc + (curr['rating'] ?? curr['Rating'] ?? 5)) / (_allReviews.isEmpty ? 1 : _allReviews.length)).toStringAsFixed(1)} / 5.0',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Star Rating Filter Tags
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildReviewFilterTag('Tất cả ($_countAll)', 'all'),
                const SizedBox(width: 8),
                _buildReviewFilterTag('5 ★ ($_count5)', '5'),
                const SizedBox(width: 8),
                _buildReviewFilterTag('4 ★ ($_count4)', '4'),
                const SizedBox(width: 8),
                _buildReviewFilterTag('3 ★ ($_count3)', '3'),
                const SizedBox(width: 8),
                _buildReviewFilterTag('2 ★ ($_count2)', '2'),
                const SizedBox(width: 8),
                _buildReviewFilterTag('1 ★ ($_count1)', '1'),
                const SizedBox(width: 8),
                _buildReviewFilterTag('Có bình luận ($_countComment)', 'comment'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reviews List
          if (_isLoadingReviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: mintColor)),
            )
          else if (_filteredReviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: const Text(
                'Chưa có đánh giá nào cho mục lọc này.',
                style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredReviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rev = _filteredReviews[index];
                final userName = (rev['userFullName'] ?? rev['UserFullName'] ?? 'Học viên').toString();
                final ratingVal = (rev['rating'] ?? rev['Rating'] ?? 5) as int;
                final contentVal = (rev['content'] ?? rev['Content'] ?? '').toString();
                final dateVal = (rev['createdAt'] ?? rev['CreatedAt'] ?? '').toString();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: mintColor.withOpacity(0.2),
                                child: const Icon(Icons.person, size: 16, color: mintColor),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                userName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (dateVal.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    dateVal.split('T')[0],
                                    style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10),
                                  ),
                                ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < ratingVal ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: const Color(0xFFFFD700),
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (contentVal.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          contentVal,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nhận xét của bạn.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      await context.read<LearningCubit>().sendFeedback(
        userId: _userId,
        courseId: widget.courseId,
        rating: _userRating,
        comment: comment,
      );

      if (mounted) {
        _commentController.clear();
        setState(() {
          _userRating = 5;
          _isSubmittingReview = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Cảm ơn đóng góp của bạn! Đánh giá đã được gửi đi.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );

        // Reload reviews list
        _loadReviews();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi đánh giá: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
