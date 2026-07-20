import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/course_category_entity.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/lesson_entity.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/learning/learning_cubit.dart';
import '../bloc/learning/learning_state.dart';
import '../widgets/course_cover_image.dart';
import 'course_details_screen.dart';

class CategoryVisuals {
  final IconData icon;
  final Color color;
  final bool isFeatured;
  final String? image;

  CategoryVisuals({
    required this.icon,
    required this.color,
    required this.isFeatured,
    this.image,
  });

  factory CategoryVisuals.fromCategory(String slug) {
    final normSlug = slug.toLowerCase();
    if (normSlug.contains('co-ban')) {
      return CategoryVisuals(
        icon: Icons.sign_language_rounded,
        color: AppTheme.primaryColor,
        isFeatured: true,
        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuU1hcKBmCMhQPYTp0CnVkyNgsz_3tqGO1j0dleUmRrsdcvrrZGK1zRyjJXaoskE3gpVfUnWFLot3z-IieBFO1i7OsLBDMn98yn1RDUCpUj_VhgbKK7kHjEq0erehKOuUcQSJJTuiCME_oK9uMh_SG8A7XIzR_73W3oor26ztQE02GrYUgC7b0Gepq95gu0HWsv1ZvISedkt1-G5p5zVHx4vSAh3DF1RBKQ2L1TtGtzT_VdxCNWjOGdHCJpEt603_a-4HKyajXlkj2U',
      );
    } else if (normSlug.contains('giao-tiep')) {
      return CategoryVisuals(
        icon: Icons.forum_rounded,
        color: AppTheme.secondaryColor,
        isFeatured: false,
        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCfaJ1WWZGNzgBcwKET34TLRZNt0fJpfvO_zF2Ea038IFJl-zRtRxdn3AEbm6S6qBADEeEL3LDY4-8NEBBD1Vr87Tql2ScmYu5GlaRsH-9s0yjS7rqrM47Uh8v7KR1XvK4LRzvhyBe3OJ8Cn84xeS46zGjh3RO1piodud6FcTzVIKz25lV4oSNAmNFaqutHT2tyXYuBQvDGzIatmyXAyfyepKScb9xlXHeGLmL0mpJtUFidTtBdZQdf29HdqvNG889wZqTiAbmUwaY',
      );
    } else if (normSlug.contains('y-te')) {
      return CategoryVisuals(
        icon: Icons.medical_services_rounded,
        color: const Color(0xFFFFB4AB),
        isFeatured: false,
        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDTRGqRr7o8KPIavbaD7ee-BAwrrKVMZIj_JoX9RiDaPD_A1GD848WhZdqjG1Z4Vi56Kw_gwOw-iK0q_5X6ktkoriCQMs5s_VBamxSdeE4_YUNfEQZx-V5w2GBOv3DXuPsy6vnyXzS8xBjIEkmc2ERyydHp6mO4f7xV4K3qt1iW9YHEMTXlqQLBRP_QTbM58Ous1OCY4cIhx60wjBKDG9tcxNlu5DJNBpKUiPqKE3GS75NWuuoSia2y2Gc9y82Jf8bc4mkqby6wi54',
      );
    } else if (normSlug.contains('cong-viec')) {
      return CategoryVisuals(
        icon: Icons.work_rounded,
        color: const Color(0xFFD0BCFF),
        isFeatured: false,
        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBxxxcMacMT7YAADtav_1xT-_9RXjR5P4KMof4OCPL8HapTX30QJyWkdzYxSCFsXc7Hq01ePLy-AMPjNbzbBuDUcbAv3VzwuTlQlIt9P0tkb4fsswsLRc2va6sMFgTgUfZR-IQlRRLbnBE7d181dGHGfoujQnZ_9jW20OA6nucJsm6-TZo6WlZLcY8YTzP_EcHGzbXYxAxuwVtOjyzbXwRBpcRrh6jg7JE1AZ7Czc25aSaxFBqi1Uy-qn8qgskjaKZUNcqgruz3Egs',
      );
    } else {
      return CategoryVisuals(
        icon: Icons.category_rounded,
        color: AppTheme.primaryColor,
        isFeatured: false,
        image: null,
      );
    }
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      int userId = 3;
      if (authState is AuthAuthenticated) {
        userId = authState.user.id;
      }
      context.read<LearningCubit>().loadCatalog(userId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCoursesBottomSheet(
    BuildContext context,
    CourseCategoryEntity category,
    List<CourseEntity> categoryCourses,
    List<LessonEntity> allLessons,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Khóa học thuộc "${category.name}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.onSurfaceVariant, size: 20),
                    onPressed: () => Navigator.pop(bottomSheetCtx),
                  )
                ],
              ),
              const SizedBox(height: 16),
              if (categoryCourses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    'Chủ đề này chưa có khóa học nào. Vui lòng quay lại sau!',
                    style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: categoryCourses.length,
                    itemBuilder: (context, index) {
                      final course = categoryCourses[index];
                      final courseLessonsCount = allLessons.where((l) => l.courseId == course.id).length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            course.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${course.level} • $courseLessonsCount bài học',
                            style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 11),
                          ),
                          trailing: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor, size: 20),
                          onTap: () {
                            Navigator.pop(bottomSheetCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailsScreen(
                                  courseId: course.id,
                                  courseTitle: course.title,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<LearningCubit, LearningState>(
      builder: (context, state) {
        if (state.isLoading && state.courses.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          );
        }

        if (state.errorMessage != null && state.courses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Lỗi kết nối máy chủ: ${state.errorMessage}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Filter courses based on search query
        final filteredCourses = state.courses.where((course) {
          final title = course.title.toLowerCase();
          return title.contains(_searchQuery.toLowerCase());
        }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bài học, khóa học...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.onSurfaceVariant),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.onSurfaceVariant),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Courses Grid / List
              Expanded(
                child: filteredCourses.isEmpty
                    ? const Center(
                        child: Text(
                          'Không tìm thấy khóa học nào phù hợp.',
                          style: TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredCourses.length,
                        itemBuilder: (context, index) {
                          final item = filteredCourses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildCourseCard(item, state.allLessons, textTheme),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(
    CourseEntity course,
    List<LessonEntity> allLessons,
    TextTheme textTheme,
  ) {
    // Count lessons for this course
    final courseLessonsCount = allLessons.where((l) => l.courseId == course.id).length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailsScreen(
              courseId: course.id,
              courseTitle: course.title,
            ),
          ),
        );
      },
      child: AppTheme.glassPanel(
        borderRadius: 20.0,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CourseCoverImage(
                  coverMediaId: course.coverMediaId,
                  defaultImageUrl: CategoryVisuals.fromCategory(course.slug).image ?? '',
                  fit: BoxFit.cover,
                ),
                // Overlay Gradient/Dimmer
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              course.level.toUpperCase(),
                              style: textTheme.labelLarge?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor, size: 18),
                        ],
                      ),
                      // Text Info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$courseLessonsCount Bài học',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
