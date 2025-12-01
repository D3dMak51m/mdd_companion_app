import 'package:dartz/dartz.dart';
import 'package:mdd_companion_app/data/models/location_payload_model.dart';
import 'package:mdd_companion_app/domain/entities/device.dart';
import '../../core/error/failures.dart';
import '../entities/device_settings.dart';

abstract class DeviceRepository {
  Future<Either<Failure, DeviceSettings>> getDeviceSettings(String deviceId);
  Future<Either<Failure, void>> updateDeviceSettings(String deviceId, DeviceSettings settings);
  Future<Either<Failure, List<Device>>> getMyDevices();
  Future<Either<Failure, void>> registerDevice(String uid, String model);
  Future<Either<Failure, void>> unlinkDevice(String uid);
  Future<Either<Failure, void>> sendLocationUpdate(String deviceUid, LocationPayloadModel payload);
}