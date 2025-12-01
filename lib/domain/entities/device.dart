import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String uid;
  final String? name;
  final String? model;
  final bool isOnline;

  const Device({
    required this.uid,
    this.name,
    this.model,
    this.isOnline = false,
  });

  @override
  List<Object?> get props => [uid, name, model, isOnline];
}