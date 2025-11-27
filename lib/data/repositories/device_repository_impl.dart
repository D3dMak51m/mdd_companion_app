import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/ble_service.dart';
import '../../../domain/entities/device_settings.dart';
import '../../../domain/repositories/device_repository.dart';
import '../models/device_settings_model.dart';

@LazySingleton(as: DeviceRepository)
class DeviceRepositoryImpl implements DeviceRepository {
  final Dio _dio;
  final BleService _bleService;

  DeviceRepositoryImpl(this._dio, this._bleService);

  @override
  Future<Either<Failure, DeviceSettings>> getDeviceSettings(String deviceId) async {
    try {
      final response = await _dio.get('/api/v1/devices/$deviceId/settings/');
      return Right(DeviceSettingsModel.fromJson(response.data));
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to load settings'));
    }
  }

  @override
  Future<Either<Failure, void>> updateDeviceSettings(String deviceId, DeviceSettings settings) async {
    try {
      final model = DeviceSettingsModel(
        fallSensitivity: settings.fallSensitivity,
        sosTimeoutSeconds: settings.sosTimeoutSeconds,
      );

      // 1. Отправка на сервер
      await _dio.patch('/api/v1/devices/$deviceId/settings/', data: model.toJson());

      // 2. Синхронизация с часами по BLE (Fire and forget)
      // Мы не ждем завершения и не фейлим операцию, если BLE недоступен
      _bleService.writeConfig(deviceId, model.toBytes());

      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to update settings'));
    }
  }
}