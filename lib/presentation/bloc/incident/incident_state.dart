part of 'incident_bloc.dart';

enum IncidentStatus {
  initial,    // Загрузка
  active,     // Просмотр
  responding, // Отправка запроса
  accepted,   // <--- НОВОЕ: Вызов принят текущим пользователем
  resolved,   // Инцидент закрыт (кем-то другим или ложная тревога)
  error,
  takenByOther // Перехвачен
}

class IncidentState extends Equatable {
  final IncidentStatus status;
  final Incident? incident;
  final String? errorMessage;

  const IncidentState({
    this.status = IncidentStatus.initial,
    this.incident,
    this.errorMessage,
  });

  // Метод для копирования состояния с сохранением старых данных
  IncidentState copyWith({
    IncidentStatus? status,
    Incident? incident,
    String? errorMessage,
  }) {
    return IncidentState(
      status: status ?? this.status,
      incident: incident ?? this.incident, // Если не передали новый, оставляем старый
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, incident, errorMessage];
}