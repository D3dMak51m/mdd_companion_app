import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';
import '../../data/datasources/local/auth_local_datasource.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio(AuthLocalDataSource authLocalDataSource) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await authLocalDataSource.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Если получили 401, пробуем обновить токен
            final newAccessToken = await _refreshToken(authLocalDataSource, dio);

            if (newAccessToken != null) {
              // Повторяем оригинальный запрос с новым токеном
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccessToken';

              try {
                final cloneReq = await dio.request(
                  opts.path,
                  options: Options(
                    method: opts.method,
                    headers: opts.headers,
                  ),
                  data: opts.data,
                  queryParameters: opts.queryParameters,
                );
                return handler.resolve(cloneReq);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  Future<String?> _refreshToken(AuthLocalDataSource authSource, Dio dio) async {
    final refreshToken = await authSource.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      // Используем отдельный инстанс Dio или обходим интерцепторы, чтобы избежать зацикливания
      // В данном случае просто делаем запрос, так как onRequest проверяет наличие токена,
      // но для refresh endpoint он нам в заголовке Authorization обычно не нужен (или нужен refresh)

      final response = await Dio(BaseOptions(baseUrl: AppConstants.baseUrl)).post(
        '/api/v1/auth/refresh/',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['access'];
        // Сохраняем новый access токен. Refresh обычно остается старым или тоже обновляется.
        // Предположим, бэкенд возвращает только access.
        await authSource.saveTokens(
            accessToken: newAccess,
            refreshToken: refreshToken
        );
        return newAccess;
      }
    } catch (e) {
      // Если refresh провалился, чистим токены (пользователь разлогинен)
      await authSource.clearTokens();
    }
    return null;
  }
}