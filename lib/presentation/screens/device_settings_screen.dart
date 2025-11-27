import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../domain/entities/device_settings.dart';
import '../bloc/device_settings/device_settings_bloc.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final String deviceId;

  const DeviceSettingsScreen({super.key, required this.deviceId});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  double _sensitivity = 5.0;
  double _timeout = 30.0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<DeviceSettingsBloc>()..add(LoadSettings(widget.deviceId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Watch Settings')),
        body: BlocConsumer<DeviceSettingsBloc, DeviceSettingsState>(
          listener: (context, state) {
            if (state.status == SettingsStatus.loaded && state.settings != null) {
              setState(() {
                _sensitivity = state.settings!.fallSensitivity.toDouble();
                _timeout = state.settings!.sosTimeoutSeconds.toDouble();
              });
            }
            if (state.status == SettingsStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved successfully')),
              );
            }
            if (state.status == SettingsStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage ?? 'Error')),
              );
            }
          },
          builder: (context, state) {
            if (state.status == SettingsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fall Sensitivity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Higher values mean easier detection (more false positives).'),
                  Slider(
                    value: _sensitivity,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _sensitivity.round().toString(),
                    onChanged: (value) => setState(() => _sensitivity = value),
                  ),
                  const SizedBox(height: 20),

                  const Text('SOS Countdown (Seconds)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Time to cancel SOS before alert is sent.'),
                  Slider(
                    value: _timeout,
                    min: 10,
                    max: 60,
                    divisions: 5,
                    label: '${_timeout.round()}s',
                    onChanged: (value) => setState(() => _timeout = value),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.status == SettingsStatus.saving
                          ? null
                          : () {
                        context.read<DeviceSettingsBloc>().add(
                          SaveSettings(
                            widget.deviceId,
                            DeviceSettings(
                              fallSensitivity: _sensitivity.round(),
                              sosTimeoutSeconds: _timeout.round(),
                            ),
                          ),
                        );
                      },
                      child: state.status == SettingsStatus.saving
                          ? const CircularProgressIndicator()
                          : const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}