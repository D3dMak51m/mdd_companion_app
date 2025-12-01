import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/repositories/incident_repository.dart';

// Events
abstract class SosHistoryEvent extends Equatable {
  const SosHistoryEvent();

  @override
  List<Object> get props => [];
}

class LoadHistory extends SosHistoryEvent {}

// States
enum HistoryStatus { initial, loading, success, failure }

class SosHistoryState extends Equatable {
  final HistoryStatus status;
  final List<Incident> incidents;
  final String? errorMessage;

  const SosHistoryState({this.status = HistoryStatus.initial, this.incidents = const [], this.errorMessage});

  @override
  List<Object?> get props => [status, incidents, errorMessage];
}

// BLoC
@injectable
class SosHistoryBloc extends Bloc<SosHistoryEvent, SosHistoryState> {
  final IncidentRepository _repository;

  SosHistoryBloc(this._repository) : super(const SosHistoryState()) {
    on<LoadHistory>((event, emit) async {
      emit(const SosHistoryState(status: HistoryStatus.loading));
      final result = await _repository.getIncidentHistory();

      result.fold((l) => emit(SosHistoryState(status: HistoryStatus.failure, errorMessage: l.message)), (r) {
        r.sort((a, b) {
          if (a.isResolved == b.isResolved) {
            return b.timestamp.compareTo(a.timestamp);
          }
          return a.isResolved ? 1 : -1;
        });

        emit(SosHistoryState(status: HistoryStatus.success, incidents: r));
      });
    });
  }
}
