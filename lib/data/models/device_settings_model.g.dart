// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceSettingsModel _$DeviceSettingsModelFromJson(Map<String, dynamic> json) =>
    DeviceSettingsModel(
      fallSensitivity: (json['fallSensitivity'] as num).toInt(),
      sosTimeoutSeconds: (json['sosTimeoutSeconds'] as num).toInt(),
    );

Map<String, dynamic> _$DeviceSettingsModelToJson(
  DeviceSettingsModel instance,
) => <String, dynamic>{
  'fallSensitivity': instance.fallSensitivity,
  'sosTimeoutSeconds': instance.sosTimeoutSeconds,
};
