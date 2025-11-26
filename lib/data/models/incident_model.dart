import '../../domain/entities/incident.dart';

class IncidentModel extends Incident {
  const IncidentModel({
    required super.id,
    required super.lat,
    required super.lon,
    required super.type,
    required super.timestamp,
  });

  factory IncidentModel.fromFcmData(Map<String, dynamic> data) {
    return IncidentModel(
      id: data['event_uid'] as String,
      lat: double.parse(data['lat'].toString()),
      lon: double.parse(data['lon'].toString()),
      type: data['type'] as String? ?? 'SOS',
      timestamp: DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now(),
    );
  }
}