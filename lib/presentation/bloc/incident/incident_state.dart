part of 'incident_bloc.dart';

enum IncidentStatus { initial, active, responding, resolved, error }

class IncidentState extends Equatable {
  final IncidentStatus status;
  final Incident? incident;
  final String? errorMessage;

  const IncidentState({
    this.status = IncidentStatus.initial,
    this.incident,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, incident, errorMessage];
}