import '../../repositories/learning_repository.dart';

class SendFeedbackUseCase {
  final LearningRepository repository;

  SendFeedbackUseCase(this.repository);

  Future<void> call({
    required int userId,
    required int courseId,
    required int rating,
    required String comment,
  }) {
    return repository.sendFeedback(
      userId: userId,
      courseId: courseId,
      rating: rating,
      comment: comment,
    );
  }
}
