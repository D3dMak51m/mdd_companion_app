import 'package:json_annotation/json_annotation.dart';

part 'location_payload_model.g.dart';

@JsonSerializable()
class LocationPayloadModel {
  final double lat;
  final double lon;

  @JsonKey(name: 'battery_level')
  final int? batteryLevel;

  final double? speed;
  final double? direction; // course
  final String? status; // "ONLINE"
  final String timestamp;

  LocationPayloadModel({
    required this.lat,
    required this.lon,
    this.batteryLevel,
    this.speed,
    this.direction,
    this.status = 'ONLINE',
    required this.timestamp,
  });

  factory LocationPayloadModel.fromJson(Map<String, dynamic> json) => _$LocationPayloadModelFromJson(json);
  Map<String, dynamic> toJson() => _$LocationPayloadModelToJson(this);
}