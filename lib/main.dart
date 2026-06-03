import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up dependency injection / instances
  final dioClient = DioClient();
  final authRemoteDataSource = AuthRemoteDataSource(dioClient);

  runApp(MyApp(
    authRemoteDataSource: authRemoteDataSource,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRemoteDataSource authRemoteDataSource;

  const MyApp({
    super.key,
    required this.authRemoteDataSource,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(authRemoteDataSource)..add(AuthCheckRequested()),
      child: MaterialApp(
        title: 'VSL Learner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
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
