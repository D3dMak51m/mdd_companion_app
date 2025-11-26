import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/error/failures.dart';
import '../../../domain/repositories/incident_repository.dart';

@LazySingleton(as: IncidentRepository)
class IncidentRepositoryImpl implements IncidentRepository {
  final Dio _dio;

  IncidentRepositoryImpl(this._dio);

  @override
  Future<Either<Failure, void>> respondToIncident(String incidentId, String status) async {
    try {
      // status: "ACCEPTED" or "FALSE_ALARM"
      await _dio.post('/api/v1/sos/$incidentId/respond/', data: {
        'status': status,
      });
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to respond'));
    }
  }
}