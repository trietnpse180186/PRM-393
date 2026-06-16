import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/auth_remote_data_source.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRemoteDataSource _authRemoteDataSource;

  AuthBloc(this._authRemoteDataSource) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final cachedUser = await _authRemoteDataSource.getCachedUser();
        if (cachedUser != null) {
          emit(AuthAuthenticated(cachedUser));
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (_) {
        emit(AuthUnauthenticated());
      }
    });

    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRemoteDataSource.login(event.email, event.password);
        emit(AuthAuthenticated(user));
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<AuthRegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRemoteDataSource.register(
          event.fullName,
          event.email,
          event.password,
        );
        emit(AuthAuthenticated(user));
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<AuthLogoutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await _authRemoteDataSource.logout();
      } catch (_) {}
      emit(AuthUnauthenticated());
    });

    on<AuthGoogleLoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRemoteDataSource.loginWithGoogle();
        emit(AuthAuthenticated(user));
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<AuthDeleteAccountRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await _authRemoteDataSource.deleteAccount(event.userId);
        emit(AuthUnauthenticated());
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll('Exception: ', '')));
      }
    });
  }
}
