part of 'incident_bloc.dart';

abstract class IncidentEvent extends Equatable {
  const IncidentEvent();
  @override
  List<Object> get props => [];
}

class IncidentLoaded extends IncidentEvent {
  final Incident incident;
  const IncidentLoaded(this.incident);
}

class IncidentResponded extends IncidentEvent {
  final String status; // "ACCEPTED" or "FALSE_ALARM"
  const IncidentResponded(this.status);
}