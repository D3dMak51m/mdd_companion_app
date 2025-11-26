import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String phone;
  final String fullName;

  const User({
    required this.id,
    required this.phone,
    required this.fullName,
  });

  @override
  List<Object?> get props => [id, phone, fullName];
}