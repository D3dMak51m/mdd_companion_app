import 'package:equatable/equatable.dart';

class Incident extends Equatable {
  final String id;
  final double lat;
  final double lon;
  final String type; // "FALL" or "SOS"
  final DateTime timestamp;

  const Incident({
    required this.id,
    required this.lat,
    required this.lon,
    required this.type,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, lat, lon, type, timestamp];
}