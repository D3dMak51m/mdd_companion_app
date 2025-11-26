import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../core/di/injection.dart';
import '../../core/services/background_service.dart';
import '../../core/services/ble_service.dart';
import '../bloc/auth/auth_bloc.dart';
import 'login_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _bleService = getIt<BleService>();
  final AppBackgroundService _bgService = getIt<AppBackgroundService>();

  List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _bgService.initialize(); // Инициализация сервиса (но не старт)
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _bleService.scanForMddDevices().listen((device) {
      if (!_devices.any((d) => d.id == device.id)) {
        setState(() {
          _devices.add(device);
        });
      }
    });
  }

  void _connectAndStartService(String deviceId) async {
    // 1. Запускаем фоновый сервис
    await _bgService.startService();

    // 2. Передаем ID устройства в сервис
    FlutterBackgroundService().invoke("setDeviceId", {"deviceId": deviceId});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to $deviceId in background...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isScanning ? null : _startScan,
              child: Text(_isScanning ? 'Scanning...' : 'Scan for MDD Watch'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                  subtitle: Text(device.id),
                  trailing: ElevatedButton(
                    onPressed: () => _connectAndStartService(device.id),
                    child: const Text('Connect'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}