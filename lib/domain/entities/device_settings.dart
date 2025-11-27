import 'package:equatable/equatable.dart';

class DeviceSettings extends Equatable {
  final int fallSensitivity; // 1 (Low) to 10 (High)
  final int sosTimeoutSeconds; // e.g., 10 to 60 seconds

  const DeviceSettings({
    required this.fallSensitivity,
    required this.sosTimeoutSeconds,
  });

  @override
  List<Object?> get props => [fallSensitivity, sosTimeoutSeconds];
}