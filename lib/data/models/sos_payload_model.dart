import 'package:json_annotation/json_annotation.dart';

part 'sos_payload_model.g.dart';

@JsonSerializable()
class SosPayloadModel {
  @JsonKey(name: 'device_uid')
  final String deviceUid;

  @JsonKey(name: 'detected_type')
  final String detectedType; // "FALL_DETECTED", "SOS_BUTTON"

  final int severity;
  final String timestamp;

  // Поля, которые мы добавляем на телефоне
  final double? lat;
  final double? lon;
  final double? altitude;

  @JsonKey(name: 'battery_level')
  final int? batteryLevel;

  @JsonKey(name: 'raw_payload')
  final Map<String, dynamic>? rawPayload;

  SosPayloadModel({
    required this.deviceUid,
    required this.detectedType,
    required this.severity,
    required this.timestamp,
    this.lat,
    this.lon,
    this.altitude,
    this.batteryLevel,
    this.rawPayload,
  });

  // Создаем копию с GPS данными
  SosPayloadModel copyWithLocation({double? lat, double? lon, double? alt}) {
    return SosPayloadModel(
      deviceUid: deviceUid,
      detectedType: detectedType,
      severity: severity,
      timestamp: timestamp,
      batteryLevel: batteryLevel,
      rawPayload: rawPayload,
      lat: lat,
      lon: lon,
      altitude: alt,
    );
  }

  factory SosPayloadModel.fromJson(Map<String, dynamic> json) => _$SosPayloadModelFromJson(json);
  Map<String, dynamic> toJson() => _$SosPayloadModelToJson(this);
}