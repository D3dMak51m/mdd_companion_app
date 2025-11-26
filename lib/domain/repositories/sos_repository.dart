import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../data/models/sos_payload_model.dart';

abstract class SosRepository {
  Future<Either<Failure, void>> sendSosSignal(SosPayloadModel payload);
}