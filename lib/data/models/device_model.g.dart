// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceModel _$DeviceModelFromJson(Map<String, dynamic> json) => DeviceModel(
  uid: json['device_uid'] as String,
  name: json['name'] as String?,
  model: json['model'] as String?,
  isOnline: json['is_online'] as bool? ?? false,
);

Map<String, dynamic> _$DeviceModelToJson(DeviceModel instance) =>
    <String, dynamic>{
      'device_uid': instance.uid,
      'name': instance.name,
      'model': instance.model,
      'is_online': instance.isOnline,
    };
