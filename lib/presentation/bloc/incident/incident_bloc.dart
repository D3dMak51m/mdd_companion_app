import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/repositories/incident_repository.dart';

part 'incident_event.dart';
part 'incident_state.dart';

@injectable
class IncidentBloc extends Bloc<IncidentEvent, IncidentState> {
  final IncidentRepository _repository;

  IncidentBloc(this._repository) : super(const IncidentState()) {
    on<IncidentLoaded>((event, emit) {
      emit(IncidentState(status: IncidentStatus.active, incident: event.incident));
    });

    on<IncidentResponded>((event, emit) async {
      if (state.incident == null) return;

      emit(IncidentState(status: IncidentStatus.responding, incident: state.incident));

      final result = await _repository.respondToIncident(state.incident!.id, event.status);

      result.fold(
            (l) => emit(IncidentState(
            status: IncidentStatus.error,
            incident: state.incident,
            errorMessage: l.message
        )),
            (r) => emit(const IncidentState(status: IncidentStatus.resolved)),
      );
    });
  }
}