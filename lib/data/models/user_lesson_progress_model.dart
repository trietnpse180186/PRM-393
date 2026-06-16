class UserLessonProgressModel {
  final int id;
  final int userId;
  final int lessonId;
  final int status; // 0 = NotStarted, 1 = InProgress, 2 = Completed
  final String? startedAt;
  final String? completedAt;
  final int lastPositionSeconds;
  final int attemptsCount;
  final double bestAccuracy;
  final double bestScore;
  final int totalTimeSeconds;
  final int xpEarned;

  UserLessonProgressModel({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.lastPositionSeconds,
    required this.attemptsCount,
    required this.bestAccuracy,
    required this.bestScore,
    required this.totalTimeSeconds,
    required this.xpEarned,
  });

  factory UserLessonProgressModel.fromJson(Map<String, dynamic> json) {
    // Backend returns status as int or string enum. Map it to int:
    final rawStatus = json['status'] ?? json['Status'];
    int statusInt = 0;
    if (rawStatus is int) {
      statusInt = rawStatus;
    } else if (rawStatus is String) {
      if (rawStatus == 'Completed') {
        statusInt = 2;
      } else if (rawStatus == 'InProgress') {
        statusInt = 1;
      } else {
        statusInt = 0;
      }
    }

    return UserLessonProgressModel(
      id: json['id'] as int? ?? json['Id'] as int? ?? 0,
      userId: json['userId'] as int? ?? json['UserId'] as int? ?? 0,
      lessonId: json['lessonId'] as int? ?? json['LessonId'] as int? ?? 0,
      status: statusInt,
      startedAt: json['startedAt'] as String? ?? json['StartedAt'] as String?,
      completedAt: json['completedAt'] as String? ?? json['CompletedAt'] as String?,
      lastPositionSeconds: json['lastPositionSeconds'] as int? ?? json['LastPositionSeconds'] as int? ?? 0,
      attemptsCount: json['attemptsCount'] as int? ?? json['AttemptsCount'] as int? ?? 0,
      bestAccuracy: (json['bestAccuracy'] ?? json['BestAccuracy'] as num? ?? 0.0).toDouble(),
      bestScore: (json['bestScore'] ?? json['BestScore'] as num? ?? 0.0).toDouble(),
      totalTimeSeconds: json['totalTimeSeconds'] as int? ?? json['TotalTimeSeconds'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? json['XpEarned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'lessonId': lessonId,
      'status': status,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'lastPositionSeconds': lastPositionSeconds,
      'attemptsCount': attemptsCount,
      'bestAccuracy': bestAccuracy,
      'bestScore': bestScore,
      'totalTimeSeconds': totalTimeSeconds,
      'xpEarned': xpEarned,
    };
  }
}
