import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/lesson_model.dart';
import '../../data/models/user_lesson_progress_model.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/learning/learning_cubit.dart';
import 'ai_grading_exercise_screen.dart';

class LessonScreen extends StatefulWidget {
  final LessonModel lesson;

  const LessonScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _isPlaying = false;
  double _videoProgress = 0.0; // Initial progress
  Timer? _progressTimer;
  int _userId = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _userId = authState.user.id;
      }
      // Trigger start lesson progress update
      context.read<LearningCubit>().startLesson(_userId, widget.lesson.id);
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) return;
        setState(() {
          if (_videoProgress < 1.0) {
            _videoProgress += 0.01; // Increment progress slowly
          } else {
            _isPlaying = false;
            _progressTimer?.cancel();
          }
        });
      });
    } else {
      _progressTimer?.cancel();
    }
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
          'Chi tiết bài học',
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
      body: Stack(
        children: [
          Container(color: AppTheme.backgroundColor),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Simulated Video Player Card
                    AppTheme.glassPanel(
                      borderRadius: 16.0,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Video Thumbnail / Cover
                              Image.network(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuDz1zgTAlhnEhDVZHik5aw5H9sOE6LhECHPoc9tqkRwtB1ePx9_Ilsl8vqltdKac7pelbOoLganFfVJwP425EIMzBNmnoFVXPMmvINbuUYsi995ybK2NMKN9ave4REW7mNyC2TIbVg_i5q_fYz84d3eIPEY2L7_WedzURs4rXr-V29nxEwPHXVykO9lHZrBtTQqhSXy91VpbCGUdDZ50xwfT-S_EIONjz3eKIc22P3PBPl-Xri8Sp8NS_2NP1zRigitqebQ_iM69OI',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.black54,
                                  child: const Center(
                                    child: Icon(Icons.video_camera_front_rounded, size: 48, color: AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                              // Play Overlay button
                              Center(
                                child: InkWell(
                                  onTap: _togglePlayPause,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.4),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      boxShadow: _isPlaying
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.primaryColor.withOpacity(0.2),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 44,
                                    ),
                                  ),
                                ),
                              ),
                              // Progress bar slider
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                      child: LinearProgressIndicator(
                                        value: _videoProgress,
                                        minHeight: 6,
                                        backgroundColor: Colors.white.withOpacity(0.12),
                                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tags row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.lesson.slug.toUpperCase().replaceAll('-', ' '),
                            style: textTheme.labelLarge?.copyWith(
                              fontSize: 9,
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                          ),
                          child: Text(
                            widget.lesson.difficultyLevel,
                            style: textTheme.labelLarge?.copyWith(
                              fontSize: 9,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Lesson Info Title & Description
                    Text(
                      widget.lesson.title,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.lesson.shortDescription ?? widget.lesson.objectiveText ?? 'Bài học ngôn ngữ ký hiệu thông dụng.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Duration and Reward info
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: AppTheme.primaryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.lesson.estimatedMinutes} phút',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '+${widget.lesson.xpReward} XP',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Bento sidebar / Action Cards
                    AppTheme.glassPanel(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AiGradingExerciseScreen(lesson: widget.lesson),
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
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_turned_in_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Kiểm tra cử chỉ',
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            tileColor: Colors.white.withOpacity(0.04),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text(
                              'Bài học tiếp theo',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                            onTap: () {
                              final state = context.read<LearningCubit>().state;
                              final currentIndex = state.currentCourseLessons.indexWhere((l) => l.id == widget.lesson.id);
                              
                              if (currentIndex != -1 && currentIndex < state.currentCourseLessons.length - 1) {
                                final nextLesson = state.currentCourseLessons[currentIndex + 1];
                                
                                // Check if next lesson is locked
                                final prog = state.currentCourseProgress.firstWhere(
                                  (p) => p.lessonId == widget.lesson.id,
                                  orElse: () => UserLessonProgressModel(
                                    id: 0,
                                    userId: _userId,
                                    lessonId: widget.lesson.id,
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bài học tiếp theo đã bị khóa. Hãy hoàn thành bài học hiện tại trước!'),
                                      backgroundColor: AppTheme.surfaceContainer,
                                    ),
                                  );
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LessonScreen(lesson: nextLesson),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bạn đã ở bài học cuối cùng của khóa học này!'),
                                    backgroundColor: AppTheme.surfaceContainer,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
