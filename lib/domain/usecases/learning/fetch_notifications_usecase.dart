import '../../repositories/learning_repository.dart';

class FetchNotificationsUseCase {
  final LearningRepository repository;

  FetchNotificationsUseCase(this.repository);

  Future<List<Map<String, dynamic>>> call(int userId) {
    return repository.fetchNotifications(userId);
  }
}
