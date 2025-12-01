import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/di/injection.dart';
import '../../domain/entities/incident.dart';
import '../bloc/incident/incident_bloc.dart';

class IncidentScreen extends StatelessWidget {
  final String incidentId;

  const IncidentScreen({super.key, required this.incidentId});

  Future<void> _openExternalMap(double lat, double lon) async {
    final Uri nativeUri = Platform.isAndroid
        ? Uri.parse("google.navigation:q=$lat,$lon&mode=d")
        : Uri.parse("https://maps.apple.com/?daddr=$lat,$lon");
    final Uri webUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lon");

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<IncidentBloc>()..add(LoadIncidentDetails(incidentId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Alert'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: BlocConsumer<IncidentBloc, IncidentState>(
          listener: (context, state) {
            // Если нажали "False Alarm" - закрываем
            if (state.status == IncidentStatus.resolved) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incident resolved as False Alarm')),
              );
            }
            // Если приняли вызов - НЕ закрываем, а показываем уведомление
            if (state.status == IncidentStatus.accepted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You accepted the request! Go to the location.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            if (state.status == IncidentStatus.takenByOther) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text("Incident Closed"),
                  content: Text(state.errorMessage ?? "Taken by another helper."),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text("OK"),
                    )
                  ],
                ),
              );
            }
            if (state.status == IncidentStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage ?? 'Error')),
              );
            }
          },
          builder: (context, state) {
            if (state.status == IncidentStatus.initial ||
                (state.status == IncidentStatus.active && state.incident == null)) {
              return const Center(child: CircularProgressIndicator(color: Colors.red));
            }

            if (state.status == IncidentStatus.error && state.incident == null) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => context.read<IncidentBloc>().add(LoadIncidentDetails(incidentId)),
                  child: const Text("Retry"),
                ),
              );
            }

            // Безопасное получение incident, так как мы проверили null выше
            final incident = state.incident!;
            final target = LatLng(incident.lat, incident.lon);

            // Проверяем, принят ли вызов мной
            final isAcceptedByMe = state.status == IncidentStatus.accepted;

            return Column(
              children: [
                // --- КАРТА ---
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: target,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('incident'),
                            position: target,
                            // Меняем цвет маркера, если приняли
                            icon: isAcceptedByMe
                                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                                : BitmapDescriptor.defaultMarker,
                            infoWindow: InfoWindow(title: incident.type),
                          ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),

                      // Кнопка навигации
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          onPressed: () => _openExternalMap(incident.lat, incident.lon),
                          label: const Text("Navigate"),
                          icon: const Icon(Icons.directions),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- ПАНЕЛЬ ДЕЙСТВИЙ ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isAcceptedByMe ? Colors.green[50] : Colors.white,
                    boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAcceptedByMe) ...[
                        // ВИД ПОСЛЕ ПРИНЯТИЯ
                        Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green, size: 30),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "YOU ARE RESPONDING",
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text("Please proceed to the location immediately."),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            // Можно добавить логику "Я прибыл" или "Отмена"
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close Map (Keep Active)'),
                          ),
                        ),
                      ] else ...[
                        // ОБЫЧНЫЙ ВИД (ДО ПРИНЯТИЯ)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incident.type.replaceAll('_', ' '),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Time: ${incident.timestamp.toLocal().toString().split('.')[0]}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                            const Icon(Icons.warning, color: Colors.red, size: 40),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (incident.isResolved)
                          const Center(
                            child: Text(
                              "INCIDENT RESOLVED",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: state.status == IncidentStatus.responding
                                      ? null
                                      : () => context.read<IncidentBloc>().add(
                                    const IncidentResponded('FALSE_ALARM'),
                                  ),
                                  child: const Text('False Alarm'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                      : const Text('I AM COMING', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                      ],
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