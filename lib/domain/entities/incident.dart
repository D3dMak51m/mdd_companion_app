import 'package:equatable/equatable.dart';
import 'user.dart'; // Импортируем сущность User

class Incident extends Equatable {
  final String id;
  final double lat;
  final double lon;
  final String type;
  final DateTime timestamp;
  final bool isResolved;
  final String status; // "NEW", "IN_PROGRESS", "RESOLVED"
  final User? acceptedBy; // Кто принял вызов

  const Incident({
    required this.id,
    required this.lat,
    required this.lon,
    required this.type,
    required this.timestamp,
    required this.isResolved,
    required this.status,
    this.acceptedBy,
  });

  @override
  List<Object?> get props => [id, lat, lon, type, timestamp, isResolved, status, acceptedBy];
}