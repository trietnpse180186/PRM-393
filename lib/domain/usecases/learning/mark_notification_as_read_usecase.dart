import '../../repositories/learning_repository.dart';

class MarkNotificationAsReadUseCase {
  final LearningRepository repository;

  MarkNotificationAsReadUseCase(this.repository);

  Future<void> call(int id) {
    return repository.markNotificationAsRead(id);
  }
}
