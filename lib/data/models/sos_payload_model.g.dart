// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sos_payload_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SosPayloadModel _$SosPayloadModelFromJson(Map<String, dynamic> json) =>
    SosPayloadModel(
      deviceUid: json['device_uid'] as String,
      detectedType: json['detected_type'] as String,
      severity: (json['severity'] as num).toInt(),
      timestamp: json['timestamp'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      batteryLevel: (json['battery_level'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SosPayloadModelToJson(SosPayloadModel instance) =>
    <String, dynamic>{
      'device_uid': instance.deviceUid,
      'detected_type': instance.detectedType,
      'severity': instance.severity,
      'timestamp': instance.timestamp,
      'lat': instance.lat,
      'lon': instance.lon,
      'altitude': instance.altitude,
      'battery_level': instance.batteryLevel,
    };
