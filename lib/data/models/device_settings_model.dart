import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_settings.dart';

part 'device_settings_model.g.dart';

@JsonSerializable()
class DeviceSettingsModel extends DeviceSettings {
  const DeviceSettingsModel({
    required super.fallSensitivity,
    required super.sosTimeoutSeconds,
  });

  factory DeviceSettingsModel.fromJson(Map<String, dynamic> json) => _$DeviceSettingsModelFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceSettingsModelToJson(this);

  // Конвертация в байты для BLE (простой протокол: [sensitivity, timeout])
  List<int> toBytes() {
    return [fallSensitivity, sosTimeoutSeconds];
  }
}