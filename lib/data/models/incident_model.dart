import '../../domain/entities/incident.dart';
import 'user_model.dart'; // Для парсинга accepted_by

class IncidentModel extends Incident {
  const IncidentModel({
    required super.id,
    required super.lat,
    required super.lon,
    required super.type,
    required super.timestamp,
    required super.isResolved,
    required super.status,
    super.acceptedBy,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['event_uid'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      type: json['detected_type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isResolved: json['resolved'] as bool? ?? false,
      status: json['status'] as String? ?? 'NEW',
      acceptedBy: json['accepted_by'] != null
          ? UserModel.fromJson(json['accepted_by'])
          : null,
    );
  }
}