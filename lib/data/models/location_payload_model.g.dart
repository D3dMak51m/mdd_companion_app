// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_payload_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocationPayloadModel _$LocationPayloadModelFromJson(
  Map<String, dynamic> json,
) => LocationPayloadModel(
  lat: (json['lat'] as num).toDouble(),
  lon: (json['lon'] as num).toDouble(),
  batteryLevel: (json['battery_level'] as num?)?.toInt(),
  speed: (json['speed'] as num?)?.toDouble(),
  direction: (json['direction'] as num?)?.toDouble(),
  status: json['status'] as String? ?? 'ONLINE',
  timestamp: json['timestamp'] as String,
);

Map<String, dynamic> _$LocationPayloadModelToJson(
  LocationPayloadModel instance,
) => <String, dynamic>{
  'lat': instance.lat,
  'lon': instance.lon,
  'battery_level': instance.batteryLevel,
  'speed': instance.speed,
  'direction': instance.direction,
  'status': instance.status,
  'timestamp': instance.timestamp,
};
