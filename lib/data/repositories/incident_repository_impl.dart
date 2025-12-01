import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/error/failures.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/repositories/incident_repository.dart';
import '../models/incident_model.dart';

@LazySingleton(as: IncidentRepository)
class IncidentRepositoryImpl implements IncidentRepository {
  final Dio _dio;

  IncidentRepositoryImpl(this._dio);

  @override
  Future<Either<Failure, Incident>> getIncidentDetails(String id) async {
    try {
      final response = await _dio.get('/api/v1/sos/$id/');
      return Right(IncidentModel.fromJson(response.data));
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to load incident details'));
    }
  }

  @override
  Future<Either<Failure, void>> respondToIncident(String incidentId, String status) async {
    try {
      final timestamp = DateTime.now().toUtc().toIso8601String();

      print("API Request: POST /api/v1/sos/$incidentId/respond/");
      print("API Body: { 'status': '$status' }");

      await _dio.post('/api/v1/sos/$incidentId/respond/', data: {'status': status, 'timestamp': timestamp});
      return const Right(null);
    } on DioException catch (e) {
      // Логируем полный ответ сервера, чтобы понять причину 400
      print("API Error Status: ${e.response?.statusCode}");
      print("API Error Data: ${e.response?.data}");

      if (e.response?.statusCode == 409) {
        final detail = e.response?.data['detail'] ?? 'Incident already taken';
        return Left(IncidentAlreadyTakenFailure(detail));
      }

      // Обработка 400 Bad Request
      if (e.response?.statusCode == 400) {
        // Сервер может вернуть: {"status": ["Invalid choice"]} или {"detail": "..."}
        final data = e.response?.data;
        String errorMessage = "Bad Request";

        if (data is Map<String, dynamic>) {
          // Собираем ошибки в одну строку
          errorMessage = data.entries.map((e) => "${e.key}: ${e.value}").join(", ");
        }

        return Left(ServerFailure(errorMessage));
      }

      return Left(ServerFailure(e.message ?? 'Failed to respond'));
    }
  }

  @override
  Future<Either<Failure, List<Incident>>> getIncidentHistory() async {
    try {
      // GET /api/v1/sos/ возвращает список
      final response = await _dio.get('/api/v1/sos/?active=true');
      final List data = response.data;

      final incidents = data.map((json) => IncidentModel.fromJson(json)).toList();

      // Сортируем: новые сверху
      incidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return Right(incidents);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to load history'));
    }
  }
}
