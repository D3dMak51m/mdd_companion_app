import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';

@lazySingleton
class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription? _connectionSubscription;

  // Stream для статуса подключения (для UI)
  final _connectionStateController = StreamController<DeviceConnectionState>.broadcast();
  Stream<DeviceConnectionState> get connectionStateStream => _connectionStateController.stream;

  // Метод для сканирования и подключения к конкретному устройству (или первому найденному с нашим UUID)
  Stream<DiscoveredDevice> scanForMddDevices() {
    return _ble.scanForDevices(
      withServices: [Uuid.parse(AppConstants.serviceUuid)],
      scanMode: ScanMode.lowLatency,
    );
  }

  void connectToDevice(String deviceId, Function(List<int>) onDataReceived) {
    _connectionSubscription?.cancel();

    _connectionSubscription = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
      servicesWithCharacteristicsToDiscover: {
        Uuid.parse(AppConstants.serviceUuid): [
          Uuid.parse(AppConstants.sosCharacteristicUuid),
          Uuid.parse(AppConstants.ackCharacteristicUuid),
        ]
      },
    ).listen((state) {
      _connectionStateController.add(state.connectionState);

      if (state.connectionState == DeviceConnectionState.connected) {
        print("BLE: Connected to $deviceId");
        _subscribeToSos(deviceId, onDataReceived);
      }
    }, onError: (e) {
      print("BLE Connection Error: $e");
    });
  }

  void _subscribeToSos(String deviceId, Function(List<int>) onDataReceived) {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.serviceUuid),
      characteristicId: Uuid.parse(AppConstants.sosCharacteristicUuid),
      deviceId: deviceId,
    );

    _ble.subscribeToCharacteristic(characteristic).listen((data) {
      print("BLE: Data received: $data");
      onDataReceived(data);
    }, onError: (e) {
      print("BLE Subscription Error: $e");
    });
  }

  Future<void> writeAck(String deviceId, bool success) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.serviceUuid),
      characteristicId: Uuid.parse(AppConstants.ackCharacteristicUuid),
      deviceId: deviceId,
    );

    // 0x01 - Success, 0x00 - Fail
    final value = success ? [0x01] : [0x00];

    try {
      await _ble.writeCharacteristicWithResponse(characteristic, value: value);
      print("BLE: ACK sent ($success)");
    } catch (e) {
      print("BLE: Failed to send ACK: $e");
    }
  }

  Future<void> writeConfig(String deviceId, List<int> configBytes) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.serviceUuid),
      characteristicId: Uuid.parse(AppConstants.configCharacteristicUuid),
      deviceId: deviceId,
    );

    try {
      await _ble.writeCharacteristicWithResponse(characteristic, value: configBytes);
      print("BLE: Config written successfully");
    } catch (e) {
      print("BLE: Failed to write config: $e");
      // Не выбрасываем ошибку критично, так как API важнее
    }
  }

    Future<void> disconnect() async {
      await _connectionSubscription?.cancel();
    }
  }