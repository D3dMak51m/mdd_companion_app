import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:mdd_companion_app/domain/repositories/auth_repository.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/notification_service.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/repositories/incident_repository.dart';

part 'incident_event.dart';

part 'incident_state.dart';

@injectable
class IncidentBloc extends Bloc<IncidentEvent, IncidentState> {
  final IncidentRepository _repository;
  final AuthRepository _authRepository;
  final NotificationService _notificationService;
  StreamSubscription? _notificationSubscription;

  IncidentBloc(this._repository, this._authRepository, this._notificationService) : super(const IncidentState()) {
    on<LoadIncidentDetails>((event, emit) async {
      emit(state.copyWith(status: IncidentStatus.initial));
      _subscribeToNotifications(event.incidentId);

      final result = await _repository.getIncidentDetails(event.incidentId);

      // Получаем сохраненный ID
      final myId = await _authRepository.getCurrentUserId();

      result.fold(
            (l) => emit(state.copyWith(status: IncidentStatus.error, errorMessage: l.message)),
            (incident) {
          IncidentStatus uiStatus = IncidentStatus.active;

          // --- DEBUG LOGS ---
          print("--- INCIDENT STATUS CHECK ---");
          print("My Local ID: '$myId'");
          print("Incident AcceptedBy ID: '${incident.acceptedBy?.id}'");
          print("Incident Status: '${incident.status}'");
          // ------------------

          if (incident.isResolved) {
            uiStatus = IncidentStatus.resolved;
          } else if (incident.status == 'IN_PROGRESS') {
            // Сравниваем как строки, чтобы избежать проблем с типами (int vs String)
            if (incident.acceptedBy != null &&
                myId != null &&
                incident.acceptedBy!.id.toString() == myId.toString()) {
              uiStatus = IncidentStatus.accepted;
            } else {
              uiStatus = IncidentStatus.takenByOther;
            }
          }

          emit(state.copyWith(
              status: uiStatus,
              incident: incident
          ));
        },
      );
    });

    on<IncidentResponded>((event, emit) async {
      if (state.incident == null) return;

      // Показываем спиннер, сохраняя инцидент
      emit(state.copyWith(status: IncidentStatus.responding));

      final result = await _repository.respondToIncident(state.incident!.id, event.status);

      result.fold(
        (failure) {
          if (failure is IncidentAlreadyTakenFailure) {
            emit(state.copyWith(status: IncidentStatus.takenByOther, errorMessage: failure.message));
          } else {
            emit(state.copyWith(status: IncidentStatus.error, errorMessage: failure.message));
          }
        },
        (success) {
          // Успех!
          if (event.status == 'ACCEPTED') {
            // Если мы приняли вызов, переходим в статус accepted
            emit(state.copyWith(status: IncidentStatus.accepted));
          } else {
            // Если ложная тревога, то закрываем
            emit(state.copyWith(status: IncidentStatus.resolved));
          }
        },
      );
    });

    on<IncidentCancelledBySystem>((event, emit) {
      emit(state.copyWith(status: IncidentStatus.takenByOther, errorMessage: event.reason));
    });
  }

  // ... _subscribeToNotifications и close без изменений
  void _subscribeToNotifications(String currentIncidentId) {
    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationService.incidentStream.listen((data) {
      final type = data['type'];
      final uid = data['sos_event_uid'] ?? data['event_uid'];

      if (uid == currentIncidentId && type == 'SOS_CANCELLED_FOR_OTHERS') {
        add(const IncidentCancelledBySystem("Incident was taken by another helper"));
      }
    });
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    return super.close();
  }
}
