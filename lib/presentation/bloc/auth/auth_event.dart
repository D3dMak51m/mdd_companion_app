part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String password;
  const AuthLoginRequested(this.phone, this.password);
}

class AuthRegisterRequested extends AuthEvent {
  final String phone;
  final String fullName;
  final String password;
  const AuthRegisterRequested(this.phone, this.fullName, this.password);
}

class AuthLogoutRequested extends AuthEvent {}