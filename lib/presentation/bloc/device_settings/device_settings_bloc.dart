import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/device_settings.dart';
import '../../../domain/repositories/device_repository.dart';

// Events
abstract class DeviceSettingsEvent extends Equatable {
  const DeviceSettingsEvent();
  @override
  List<Object> get props => [];
}

class LoadSettings extends DeviceSettingsEvent {
  final String deviceId;
  const LoadSettings(this.deviceId);
}

class SaveSettings extends DeviceSettingsEvent {
  final String deviceId;
  final DeviceSettings settings;
  const SaveSettings(this.deviceId, this.settings);
}

// States
enum SettingsStatus { initial, loading, loaded, saving, success, error }

class DeviceSettingsState extends Equatable {
  final SettingsStatus status;
  final DeviceSettings? settings;
  final String? errorMessage;

  const DeviceSettingsState({
    this.status = SettingsStatus.initial,
    this.settings,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, settings, errorMessage];
}

// BLoC
@injectable
class DeviceSettingsBloc extends Bloc<DeviceSettingsEvent, DeviceSettingsState> {
  final DeviceRepository _repository;

  DeviceSettingsBloc(this._repository) : super(const DeviceSettingsState()) {
    on<LoadSettings>((event, emit) async {
      emit(const DeviceSettingsState(status: SettingsStatus.loading));
      final result = await _repository.getDeviceSettings(event.deviceId);
      result.fold(
            (l) => emit(DeviceSettingsState(status: SettingsStatus.error, errorMessage: l.message)),
            (r) => emit(DeviceSettingsState(status: SettingsStatus.loaded, settings: r)),
      );
    });

    on<SaveSettings>((event, emit) async {
      emit(DeviceSettingsState(status: SettingsStatus.saving, settings: state.settings));
      final result = await _repository.updateDeviceSettings(event.deviceId, event.settings);
      result.fold(
            (l) => emit(DeviceSettingsState(
            status: SettingsStatus.error,
            errorMessage: l.message,
            settings: state.settings // Keep old settings on error
        )),
            (r) => emit(DeviceSettingsState(
            status: SettingsStatus.success,
            settings: event.settings
        )),
      );
    });
  }
}