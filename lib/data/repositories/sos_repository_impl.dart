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
      final data = payload.toJson();
      print("SOS Repo: Sending payload: $data");

      await _dio.post('/api/v1/sos/trigger/', data: data);
      return const Right(null);
    } on DioException catch (e) {
      // Логируем ответ сервера, чтобы видеть причину 400
      print("SOS Repo Error Status: ${e.response?.statusCode}");
      print("SOS Repo Error Body: ${e.response?.data}");

      if (e.response?.statusCode == 400) {
        // Возвращаем текст ошибки от сервера
        return Left(ServerFailure("Validation Error: ${e.response?.data}"));
      }

      return Left(ServerFailure(e.message ?? 'Failed to send SOS'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}