import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/device_settings.dart';

abstract class DeviceRepository {
  Future<Either<Failure, DeviceSettings>> getDeviceSettings(String deviceId);
  Future<Either<Failure, void>> updateDeviceSettings(String deviceId, DeviceSettings settings);
}