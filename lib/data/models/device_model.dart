import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device.dart';

part 'device_model.g.dart';

@JsonSerializable()
class DeviceModel extends Device {
  const DeviceModel({
    @JsonKey(name: 'device_uid') required super.uid,
    super.name,
    super.model,
    @JsonKey(name: 'is_online', defaultValue: false) super.isOnline,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => _$DeviceModelFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceModelToJson(this);
}