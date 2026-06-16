import 'package:flutter_test/flutter_test.dart';
import 'package:vietnamese_sign_language_platform/main.dart';
import 'package:vietnamese_sign_language_platform/core/network/dio_client.dart';
import 'package:vietnamese_sign_language_platform/data/datasources/auth_remote_data_source.dart';
import 'package:vietnamese_sign_language_platform/data/datasources/learning_remote_data_source.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    final dioClient = DioClient();
    final authRemoteDataSource = AuthRemoteDataSource(dioClient);
    final learningRemoteDataSource = LearningRemoteDataSource(dioClient);
    
    await tester.pumpWidget(MyApp(
      authRemoteDataSource: authRemoteDataSource,
      learningRemoteDataSource: learningRemoteDataSource,
    ));
    
    expect(find.byType(MyApp), findsOneWidget);
  });
}
