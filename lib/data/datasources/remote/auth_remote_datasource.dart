import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String phone, String password);
  Future<Map<String, dynamic>> register(String phone, String fullName, String password);
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await _dio.post('/api/v1/auth/login/', data: {
      'phone_number': phone,
      'password': password,
    });
    return response.data;
  }

  @override
  Future<Map<String, dynamic>> register(String phone, String fullName, String password) async {
    final response = await _dio.post('/api/v1/auth/register/', data: {
      'phone_number': phone,
      'full_name': fullName,
      'password': password,
      'password2': password, // Бэкенд требует подтверждение
    });
    return response.data;
  }
}