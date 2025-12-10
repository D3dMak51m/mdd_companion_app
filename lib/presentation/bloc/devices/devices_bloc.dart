import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/device.dart';
import '../../../domain/repositories/device_repository.dart';

// Events
abstract class DevicesEvent extends Equatable {
  const DevicesEvent();
  @override
  List<Object> get props => [];
}

class LoadDevices extends DevicesEvent {}

class AddDevice extends DevicesEvent {
  final String uid;
  final String model;
  const AddDevice(this.uid, this.model);
}

class RemoveDevice extends DevicesEvent {
  final String uid;
  const RemoveDevice(this.uid);
}

class DeviceConnectionChanged extends DevicesEvent {
  final String? connectedDeviceId;
  const DeviceConnectionChanged(this.connectedDeviceId);
}

// States
enum DevicesStatus { initial, loading, success, failure }

class DevicesState extends Equatable {
  final DevicesStatus status;
  final List<Device> devices;
  final String? errorMessage;
  final String? connectedDeviceId;

  const DevicesState({
    this.status = DevicesStatus.initial,
    this.devices = const [],
    this.errorMessage,
    this.connectedDeviceId,
  });

  DevicesState copyWith({
    DevicesStatus? status,
    List<Device>? devices,
    String? errorMessage,
    String? connectedDeviceId,
  }) {
    return DevicesState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedDeviceId: connectedDeviceId ?? this.connectedDeviceId,
    );
  }

  @override
  List<Object?> get props => [status, devices, errorMessage, connectedDeviceId];
}

// BLoC
@injectable
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  final DeviceRepository _repository;

  DevicesBloc(this._repository) : super(const DevicesState()) {

    on<LoadDevices>((event, emit) async {
      emit(state.copyWith(status: DevicesStatus.loading));
      final result = await _repository.getMyDevices();

      result.fold(
            (l) => emit(state.copyWith(status: DevicesStatus.failure, errorMessage: l.message)),
            (devices) {
          // Сортируем список перед отправкой в стейт
          final sortedDevices = _sortDevices(devices, state.connectedDeviceId);
          emit(state.copyWith(status: DevicesStatus.success, devices: sortedDevices));
        },
      );
    });

    // Обработка подключения
    on<DeviceConnectionChanged>((event, emit) async {
      if (event.connectedDeviceId != null) {
        // Сохраняем время подключения
        await _repository.saveLastConnectedTime(event.connectedDeviceId!);
      }

      // Обновляем ID и пересортировываем текущий список
      final sortedDevices = _sortDevices(state.devices, event.connectedDeviceId);

      emit(state.copyWith(
        connectedDeviceId: event.connectedDeviceId,
        devices: sortedDevices,
      ));
    });

    on<AddDevice>((event, emit) async {
      emit(const DevicesState(status: DevicesStatus.loading));
      final result = await _repository.registerDevice(event.uid, event.model);

      result.fold(
            (l) => emit(DevicesState(status: DevicesStatus.failure, errorMessage: l.message)),
            (r) {
          // После успешного добавления перезагружаем список
          add(LoadDevices());
        },
      );
    });

    on<RemoveDevice>((event, emit) async {
      final result = await _repository.unlinkDevice(event.uid);
      result.fold(
            (l) => null,
            (r) => add(LoadDevices()),
      );
    });
  }

  // Логика сортировки
  List<Device> _sortDevices(List<Device> devices, String? activeId) {
    // Создаем изменяемую копию
    final List<Device> sorted = List.from(devices);

    sorted.sort((a, b) {
      // 1. Подключенное устройство всегда сверху
      if (a.uid == activeId) return -1;
      if (b.uid == activeId) return 1;

      // 2. Сортировка по времени последнего подключения (новые сверху)
      final lastSeenA = _repository.getLastConnectedTime(a.uid);
      final lastSeenB = _repository.getLastConnectedTime(b.uid);
      return lastSeenB.compareTo(lastSeenA);
    });

    return sorted;
  }
}