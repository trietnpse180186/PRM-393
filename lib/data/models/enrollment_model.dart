class EnrollmentModel {
  final int id;
  final int userId;
  final int courseId;
  final double progressPercent;
  final String status;

  EnrollmentModel({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.progressPercent,
    required this.status,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    // Backend returns status as int or string enum. Map it to string:
    final rawStatus = json['status'] ?? json['Status'];
    String statusStr = 'Enrolled';
    if (rawStatus is int) {
      if (rawStatus == 1) {
        statusStr = 'InProgress';
      } else if (rawStatus == 2) {
        statusStr = 'Completed';
      }
    } else if (rawStatus is String) {
      statusStr = rawStatus;
    }

    return EnrollmentModel(
      id: json['id'] as int? ?? json['Id'] as int? ?? 0,
      userId: json['userId'] as int? ?? json['UserId'] as int? ?? 0,
      courseId: json['courseId'] as int? ?? json['CourseId'] as int? ?? 0,
      progressPercent: (json['progressPercent'] ?? json['ProgressPercent'] as num? ?? 0.0).toDouble(),
      status: statusStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'courseId': courseId,
      'progressPercent': progressPercent,
      'status': status,
    };
  }
}
