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

// States
enum DevicesStatus { initial, loading, success, failure }

class DevicesState extends Equatable {
  final DevicesStatus status;
  final List<Device> devices;
  final String? errorMessage;

  const DevicesState({
    this.status = DevicesStatus.initial,
    this.devices = const [],
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, devices, errorMessage];
}

// BLoC
@injectable
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  final DeviceRepository _repository;

  DevicesBloc(this._repository) : super(const DevicesState()) {
    on<LoadDevices>((event, emit) async {
      emit(const DevicesState(status: DevicesStatus.loading));
      final result = await _repository.getMyDevices();
      result.fold(
            (l) => emit(DevicesState(status: DevicesStatus.failure, errorMessage: l.message)),
            (r) => emit(DevicesState(status: DevicesStatus.success, devices: r)),
      );
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
}