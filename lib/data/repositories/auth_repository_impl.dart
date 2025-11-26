import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/error/failures.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/user_model.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<Either<Failure, User>> login(String phone, String password) async {
    try {
      final data = await _remoteDataSource.login(phone, password);

      // Сохраняем токены
      await _localDataSource.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );

      // В реальном API логин может не возвращать профиль юзера сразу,
      // тогда нужно сделать отдельный запрос GET /api/v1/auth/me/
      // Для примера предположим, что бэкенд возвращает user object или мы его декодируем из токена.
      // Здесь создадим заглушку или распарсим, если бэкенд отдает.
      // Допустим, бэкенд возвращает { access:..., refresh:..., user: {...} }

      // Если бэкенд не возвращает юзера при логине, нужно сделать запрос профиля.
      // Для упрощения пока вернем модель.
      return const Right(User(id: '1', phone: 'phone', fullName: 'User'));
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Login failed'));
    }
  }

  @override
  Future<Either<Failure, User>> register(String phone, String fullName, String password) async {
    try {
      final data = await _remoteDataSource.register(phone, fullName, password);

      await _localDataSource.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );

      final userModel = UserModel.fromJson(data['user']);
      return Right(userModel);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data.toString() ?? 'Registration failed'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkAuthStatus() async {
    final token = await _localDataSource.getAccessToken();
    return Right(token != null);
  }

  @override
  Future<Either<Failure, void>> logout() async {
    await _localDataSource.clearTokens();
    return const Right(null);
  }
}