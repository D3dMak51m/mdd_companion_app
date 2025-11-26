import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final result = await _authRepository.checkAuthStatus();
    result.fold(
          (l) => emit(const AuthState(status: AuthStatus.unauthenticated)),
          (isAuthenticated) => emit(AuthState(
        status: isAuthenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      )),
    );
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState(status: AuthStatus.loading));
    final result = await _authRepository.login(event.phone, event.password);
    result.fold(
          (l) => emit(AuthState(status: AuthStatus.error, errorMessage: l.message)),
          (user) => emit(AuthState(status: AuthStatus.authenticated, user: user)),
    );
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState(status: AuthStatus.loading));
    final result = await _authRepository.register(event.phone, event.fullName, event.password);
    result.fold(
          (l) => emit(AuthState(status: AuthStatus.error, errorMessage: l.message)),
          (user) => emit(AuthState(status: AuthStatus.authenticated, user: user)),
    );
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}