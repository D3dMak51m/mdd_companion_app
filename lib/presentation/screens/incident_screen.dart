import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/di/injection.dart';
import '../../domain/entities/incident.dart';
import '../bloc/incident/incident_bloc.dart';

class IncidentScreen extends StatelessWidget {
  final Incident incident;

  const IncidentScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<IncidentBloc>()..add(IncidentLoaded(incident)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('SOS: ${incident.type}'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: BlocConsumer<IncidentBloc, IncidentState>(
          listener: (context, state) {
            if (state.status == IncidentStatus.resolved) {
              Navigator.of(context).pop(); // Закрываем экран после ответа
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Response sent successfully')),
              );
            }
            if (state.status == IncidentStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage ?? 'Error')),
              );
            }
          },
          builder: (context, state) {
            final target = LatLng(incident.lat, incident.lon);

            return Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: target,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('incident'),
                        position: target,
                        infoWindow: InfoWindow(title: incident.type),
                      ),
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Incident detected at ${incident.timestamp}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onPressed: state.status == IncidentStatus.responding
                                  ? null
                                  : () => context.read<IncidentBloc>().add(
                                const IncidentResponded('FALSE_ALARM'),
                              ),
                              child: const Text('False Alarm'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              onPressed: state.status == IncidentStatus.responding
                                  ? null
                                  : () => context.read<IncidentBloc>().add(
                                const IncidentResponded('ACCEPTED'),
                              ),
                              child: state.status == IncidentStatus.responding
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                                  : const Text('I AM COMING'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}