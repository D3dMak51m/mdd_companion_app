import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/user.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.phone,
    required super.fullName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      // Ищем ID во всех возможных полях
      id: (json['uuid'] ?? json['id'] ?? json['pk'] ?? '').toString(),
      phone: (json['phone_number'] ?? json['phone'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['name'] ?? 'Unknown').toString(),
    );
  }

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}