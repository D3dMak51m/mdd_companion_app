import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';

abstract class IncidentRepository {
  Future<Either<Failure, void>> respondToIncident(String incidentId, String status);
}