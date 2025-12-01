part of 'incident_bloc.dart';

abstract class IncidentEvent extends Equatable {
  const IncidentEvent();

  @override
  List<Object> get props => [];
}

/// Событие для загрузки деталей инцидента по ID (приходит из Push)
class LoadIncidentDetails extends IncidentEvent {
  final String incidentId;
  const LoadIncidentDetails(this.incidentId);

  @override
  List<Object> get props => [incidentId];
}

/// Событие ответа на инцидент (Принять / Ложная тревога)
class IncidentResponded extends IncidentEvent {
  final String status; // "ACCEPTED" or "FALSE_ALARM"
  const IncidentResponded(this.status);

  @override
  List<Object> get props => [status];
}

class IncidentCancelledBySystem extends IncidentEvent {
  final String reason;
  const IncidentCancelledBySystem(this.reason);
}