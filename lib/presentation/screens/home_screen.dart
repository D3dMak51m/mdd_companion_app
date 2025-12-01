import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:intl/intl.dart'; // Не забудьте добавить intl в pubspec.yaml
import 'package:mdd_companion_app/domain/repositories/auth_repository.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di/injection.dart';
import '../../core/services/background_service.dart';
import '../../core/services/ble_service.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/devices/devices_bloc.dart';
import '../bloc/history/sos_history_bloc.dart'; // Импорт BLoC истории
import 'device_settings_screen.dart';
import 'incident_screen.dart'; // Импорт экрана инцидента
import 'login_screen.dart';
import 'qr_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // У нас теперь 3 вкладки
    _tabController = TabController(length: 3, vsync: this);
    getIt<AppBackgroundService>().initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<DevicesBloc>()..add(LoadDevices()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MDD Companion'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'My Devices', icon: Icon(Icons.watch)),
              Tab(text: 'Add Device', icon: Icon(Icons.add_link)),
              Tab(text: 'History', icon: Icon(Icons.history)), // Вкладка истории
            ],
          ),
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
        body: TabBarView(
          controller: _tabController,
          children: const [
            _MyDevicesTab(),
            _ScanDevicesTab(),
            _HistoryTab(), // Виджет истории
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// TAB 1: My Devices (Список привязанных устройств)
// ==============================================================================
class _MyDevicesTab extends StatelessWidget {
  const _MyDevicesTab();

  void _connectAndStartService(BuildContext context, String deviceId) async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (!isRunning) {
      await getIt<AppBackgroundService>().startService();
    }
    service.invoke("setDeviceId", {"deviceId": deviceId});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to $deviceId in background...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicesBloc, DevicesState>(
      builder: (context, state) {
        if (state.status == DevicesStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == DevicesStatus.failure) {
          return Center(child: Text('Error: ${state.errorMessage}'));
        }
        if (state.devices.isEmpty) {
          return const Center(child: Text('No devices linked. Go to "Add Device" tab.'));
        }

        return ListView.builder(
          itemCount: state.devices.length,
          itemBuilder: (context, index) {
            final device = state.devices[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.watch, size: 40),
                title: Text(device.name ?? 'MDD Watch'),
                subtitle: Text(device.uid),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DeviceSettingsScreen(deviceId: device.uid),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        context.read<DevicesBloc>().add(RemoveDevice(device.uid));
                      },
                    ),
                  ],
                ),
                onTap: () => _connectAndStartService(context, device.uid),
              ),
            );
          },
        );
      },
    );
  }
}

// ==============================================================================
// TAB 2: Scan Devices (Поиск и Привязка)
// ==============================================================================
class _ScanDevicesTab extends StatefulWidget {
  const _ScanDevicesTab();

  @override
  State<_ScanDevicesTab> createState() => _ScanDevicesTabState();
}

class _ScanDevicesTabState extends State<_ScanDevicesTab> {
  final BleService _bleService = getIt<BleService>();
  List<DiscoveredDevice> _scannedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.camera,
      ].request();
    }
  }

  void _startManualScan() async {
    if (Platform.isAndroid) {
      if (!await Permission.bluetoothScan.isGranted || !await Permission.location.isGranted) {
        await _requestPermissions();
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
    });

    try {
      _scanSubscription?.cancel();
      _scanSubscription = _bleService.scanForMddDevices().listen((device) {
        if (!_scannedDevices.any((d) => d.id == device.id)) {
          setState(() {
            _scannedDevices.add(device);
          });
        }
      }, onError: (e) {
        print("Scan Error: $e");
        setState(() => _isScanning = false);
      });
    } catch (e) {
      print("Critical Scan Error: $e");
      setState(() => _isScanning = false);
    }
  }

  void _scanQrCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScanScreen()),
    );

    if (result != null && mounted) {
      String targetUid = result;

      if (result.toString().trim().startsWith("{")) {
        try {
          final Map<String, dynamic> data = jsonDecode(result);
          targetUid = data['device_uid'] ?? targetUid;
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Scanned: $targetUid. Searching for device...'),
          duration: const Duration(seconds: 10),
        ),
      );

      _findDeviceByUid(targetUid);
    }
  }

  void _findDeviceByUid(String targetName) {
    setState(() {
      _isScanning = true;
    });

    _scanSubscription?.cancel();

    _scanSubscription = _bleService.scanForMddDevices().listen((device) {
      if (device.name == targetName) {
        _scanSubscription?.cancel();
        setState(() {
          _isScanning = false;
        });

        context.read<DevicesBloc>().add(AddDevice(device.id, targetName));
        _finalizePairing(device.id);
      }
    }, onError: (e) {
      setState(() => _isScanning = false);
    });

    Future.delayed(const Duration(seconds: 15), () {
      if (_isScanning) {
        _scanSubscription?.cancel();
        if (mounted) {
          setState(() => _isScanning = false);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device not found nearby.')),
          );
        }
      }
    });
  }

  void _finalizePairing(String deviceId) async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) await getIt<AppBackgroundService>().startService();

    service.invoke("setDeviceId", {"deviceId": deviceId});
    await Future.delayed(const Duration(seconds: 4));

    service.invoke("sendInitialConfig", {
      "deviceId": deviceId,
      "sensitivity": 5,
      "timeout": 30
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pairing complete! Watch $deviceId connected.')),
      );
    }
  }

  void _registerBleDevice(DiscoveredDevice device) {
    context.read<DevicesBloc>().add(AddDevice(device.id, device.name));
    _finalizePairing(device.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _isScanning ? null : _scanQrCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isScanning
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(_isScanning ? 'Scanning...' : 'Manual Scan'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _isScanning ? null : _startManualScan,
                ),
              ),
            ],
          ),
        ),
        if (_isScanning) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _scannedDevices.length,
            itemBuilder: (context, index) {
              final device = _scannedDevices[index];
              return ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                subtitle: Text("${device.id}\nRSSI: ${device.rssi}"),
                trailing: ElevatedButton(
                  onPressed: () => _registerBleDevice(device),
                  child: const Text('Link'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// TAB 3: History (История инцидентов)
// ==============================================================================
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }
  void _loadUserId() async {
    _myUserId = await getIt<AuthRepository>().getCurrentUserId();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Создаем провайдер здесь, чтобы он жил пока жива вкладка
    return BlocProvider(
      create: (context) => getIt<SosHistoryBloc>()..add(LoadHistory()),
      child: Scaffold(
        body: BlocBuilder<SosHistoryBloc, SosHistoryState>(
          builder: (context, state) {
            if (state.status == HistoryStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == HistoryStatus.failure) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.errorMessage}'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => context.read<SosHistoryBloc>().add(LoadHistory()),
                      child: const Text('Retry'),
                    )
                  ],
                ),
              );
            }
            if (state.incidents.isEmpty) {
              return const Center(child: Text('No SOS history found.'));
            }

            return RefreshIndicator(
              onRefresh: () async => context.read<SosHistoryBloc>().add(LoadHistory()),
              child: ListView.builder(
                itemCount: state.incidents.length,
                itemBuilder: (context, index) {
                  final incident = state.incidents[index];

                  // ОПРЕДЕЛЕНИЕ СТАТУСА ДЛЯ UI
                  bool isMyCase = incident.acceptedBy != null &&
                      _myUserId != null &&
                      incident.acceptedBy!.id == _myUserId;
                  bool isTaken = incident.status == 'IN_PROGRESS';
                  bool isResolved = incident.isResolved;

                  Color cardColor = Colors.white;
                  Color statusColor = Colors.grey;
                  IconData statusIcon = Icons.help_outline;
                  String statusText = "New";

                  if (isResolved) {
                    statusText = "Resolved";
                    statusIcon = Icons.check_circle;
                    statusColor = Colors.green;
                    cardColor = Colors.grey.shade50;
                  } else if (isMyCase) {
                    statusText = "Accepted by You";
                    statusIcon = Icons.directions_run;
                    statusColor = Colors.blue;
                    cardColor = Colors.blue.shade50; // Подсветка моих активных
                  } else if (isTaken) {
                    statusText = "In Progress";
                    statusIcon = Icons.timelapse;
                    statusColor = Colors.orange;
                  } else {
                    // NEW
                    statusText = "SOS Alert";
                    statusIcon = Icons.warning_amber_rounded;
                    statusColor = Colors.red;
                    cardColor = Colors.red.shade50; // Подсветка новых
                  }

                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.2),
                        child: Icon(statusIcon, color: statusColor),
                      ),
                      title: Text(
                        incident.type.replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd MMM, HH:mm').format(incident.timestamp.toLocal())),
                          if (isTaken && !isMyCase && incident.acceptedBy != null)
                            Text("Helper: ${incident.acceptedBy!.fullName}", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => IncidentScreen(incidentId: incident.id),
                          ),
                        ).then((_) {
                          // Обновляем список при возврате
                          context.read<SosHistoryBloc>().add(LoadHistory());
                        });
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}