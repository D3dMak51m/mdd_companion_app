import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  AuthRepositoryImpl(
      this._remoteDataSource,
      this._localDataSource,
      );

  /// Приватный метод для синхронизации FCM токена с сервером
  Future<void> _syncFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _remoteDataSource.updateFcmToken(token);
        print("AuthRepository: FCM Token synced: $token");
      }
    } catch (e) {
      print("AuthRepository: Failed to sync FCM token: $e");
      // Не прерываем работу, если пуши не настроились, это не критично для входа
    }
  }

  @override
  Future<String?> getCurrentUserId() async {
    return await _localDataSource.getUserId();
  }

  @override
  Future<Either<Failure, User>> login(String phone, String password) async {
    try {
      final data = await _remoteDataSource.login(phone, password);

      // 1. Сохраняем токены
      await _localDataSource.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );

      UserModel userModel;

      // 2. Безопасный парсинг пользователя
      if (data['user'] != null && data['user'] is Map<String, dynamic>) {
        userModel = UserModel.fromJson(data['user']);

        // 3. Сохраняем ID пользователя (КРИТИЧНО для логики инцидентов)
        await _localDataSource.saveUserId(userModel.id);
        print("AuthRepository: User ID saved: ${userModel.id}");
      } else {
        // Если сервер не вернул объект user, мы в сложной ситуации.
        // В идеале нужно сделать запрос GET /auth/me/ (если есть такой эндпоинт).
        // Если нет - мы не знаем ID юзера.

        // Для стабильности возвращаем ошибку, чтобы UI не завис,
        // или создаем временную модель, если ID не критичен прямо сейчас (но он критичен).
        print("AuthRepository Error: Backend response missing 'user' object");
        return Left(const ServerFailure("Login successful, but user data missing."));
      }

      // 4. Обновляем FCM токен
      await _syncFcmToken();

      return Right(userModel);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data.toString() ?? e.message ?? 'Login failed'));
    } catch (e) {
      print("AuthRepository Critical Error: $e");
      return Left(ServerFailure(e.toString()));
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

      // При регистрации обычно возвращается полный объект
      final userModel = UserModel.fromJson(data['user']);

      // Сохраняем ID
      await _localDataSource.saveUserId(userModel.id);

      await _syncFcmToken();

      return Right(userModel);
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data.toString() ?? 'Registration failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> checkAuthStatus() async {
    try {
      final token = await _localDataSource.getAccessToken();
      final hasToken = token != null;

      if (hasToken) {
        // Если мы авторизованы, на всякий случай обновим токен пушей
        _syncFcmToken();
      }

      return Right(hasToken);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Очищаем всё: токены и ID пользователя
      await _localDataSource.clearTokens();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure("Failed to logout locally"));
    }
  }
}