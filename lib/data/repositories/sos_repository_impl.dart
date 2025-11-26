import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/error/failures.dart';
import '../../../domain/repositories/sos_repository.dart';
import '../models/sos_payload_model.dart';

@LazySingleton(as: SosRepository)
class SosRepositoryImpl implements SosRepository {
  final Dio _dio;

  SosRepositoryImpl(this._dio);

  @override
  Future<Either<Failure, void>> sendSosSignal(SosPayloadModel payload) async {
    try {
      await _dio.post('/api/v1/sos/trigger/', data: payload.toJson());
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to send SOS'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}