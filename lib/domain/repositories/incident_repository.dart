import 'package:dartz/dartz.dart';
import 'package:mdd_companion_app/core/error/failures.dart';
import 'package:mdd_companion_app/domain/entities/incident.dart';

abstract class IncidentRepository {
  Future<Either<Failure, Incident>> getIncidentDetails(String id);

  Future<Either<Failure, void>> respondToIncident(String incidentId, String status);

  Future<Either<Failure, List<Incident>>> getIncidentHistory();
}
