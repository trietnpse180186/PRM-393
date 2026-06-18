import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'core/services/push_notification_service.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/datasources/learning_remote_data_source.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/bloc/learning/learning_cubit.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Push Notification Service
  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();
  
  // Set up dependency injection / instances
  final dioClient = DioClient();
  final authRemoteDataSource = AuthRemoteDataSource(dioClient);
  final learningRemoteDataSource = LearningRemoteDataSource(dioClient);

  runApp(MyApp(
    authRemoteDataSource: authRemoteDataSource,
    learningRemoteDataSource: learningRemoteDataSource,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRemoteDataSource authRemoteDataSource;
  final LearningRemoteDataSource learningRemoteDataSource;

  const MyApp({
    super.key,
    required this.authRemoteDataSource,
    required this.learningRemoteDataSource,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRemoteDataSource>.value(value: authRemoteDataSource),
        RepositoryProvider<LearningRemoteDataSource>.value(value: learningRemoteDataSource),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(authRemoteDataSource)..add(AuthCheckRequested()),
          ),
          BlocProvider<LearningCubit>(
            create: (context) => LearningCubit(learningRemoteDataSource),
          ),
        ],
        child: MaterialApp(
          title: 'VSL Learner',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const HomeScreen();
        } else if (state is AuthUnauthenticated || state is AuthFailure) {
          return const WelcomeScreen();
        }
        
        // Splash / Initial Loading State
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        );
      },
    );
  }
}
