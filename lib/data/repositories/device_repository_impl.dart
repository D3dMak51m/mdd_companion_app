import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:mdd_companion_app/core/constants/app_constants.dart';
import 'package:mdd_companion_app/data/models/device_model.dart';
import 'package:mdd_companion_app/data/models/location_payload_model.dart';
import 'package:mdd_companion_app/domain/entities/device.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/ble_service.dart';
import '../../../domain/entities/device_settings.dart';
import '../../../domain/repositories/device_repository.dart';
import '../models/device_settings_model.dart';

@LazySingleton(as: DeviceRepository)
class DeviceRepositoryImpl implements DeviceRepository {
  final Dio _dio;
  final BleService _bleService;
  final Box _settingsBox = Hive.box(AppConstants.settingsBoxName);
  DeviceRepositoryImpl(this._dio, this._bleService);

  @override
  Future<Either<Failure, DeviceSettings>> getDeviceSettings(String deviceId) async {
    try {
      // Читаем из локального хранилища. Если нет - возвращаем дефолтные.
      final sensitivity = _settingsBox.get('${deviceId}_sensitivity', defaultValue: 5);
      final timeout = _settingsBox.get('${deviceId}_timeout', defaultValue: 30);

      return Right(DeviceSettings(
        fallSensitivity: sensitivity,
        sosTimeoutSeconds: timeout,
      ));
    } catch (e) {
      return Left(CacheFailure('Failed to load local settings'));
    }
  }

  @override
  Future<Either<Failure, void>> updateDeviceSettings(String deviceId, DeviceSettings settings) async {
    try {
      // 1. Пытаемся записать в часы по BLE
      await _bleService.writeConfig(
          deviceId,
          settings.fallSensitivity,
          settings.sosTimeoutSeconds
      );

      // 2. Если запись прошла успешно, сохраняем в локальный кэш (Hive)
      await _settingsBox.put('${deviceId}_sensitivity', settings.fallSensitivity);
      await _settingsBox.put('${deviceId}_timeout', settings.sosTimeoutSeconds);

      return const Right(null);
    } catch (e) {
      // Если BLE недоступен, возвращаем ошибку, так как это единственный способ изменить настройки
      return Left(ServerFailure('Watch is not connected via BLE. Cannot update settings.'));
    }
  }

  @override
  Future<Either<Failure, List<Device>>> getMyDevices() async {
    try {
      final response = await _dio.get('/api/v1/devices/');
      final List data = response.data;
      final devices = data.map((e) => DeviceModel.fromJson(e)).toList();
      return Right(devices);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to fetch devices'));
    }
  }

  @override
  Future<Either<Failure, void>> registerDevice(String uid, String model) async {
    try {
      await _dio.post('/api/v1/devices/', data: {
        'device_uid': uid,
        'model': model,
      });
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to register device'));
    }
  }

  @override
  Future<Either<Failure, void>> unlinkDevice(String uid) async {
    try {
      await _dio.delete('/api/v1/devices/$uid/');
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to unlink device'));
    }
  }

  @override
  Future<Either<Failure, void>> sendLocationUpdate(String deviceUid, LocationPayloadModel payload) async {
    try {
      await _dio.post('/api/v1/devices/$deviceUid/location/', data: payload.toJson());
      return const Right(null);
    } on DioException catch (e) {
      // Логируем, но для трекинга это не критично, просто пропускаем точку
      return Left(ServerFailure(e.message ?? 'Failed to send location'));
    }
  }

  @override
  Future<void> saveLastConnectedTime(String deviceId) async {
    await _settingsBox.put('last_seen_$deviceId', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  int getLastConnectedTime(String deviceId) {
    return _settingsBox.get('last_seen_$deviceId', defaultValue: 0);
  }
}