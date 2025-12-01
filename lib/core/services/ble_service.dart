import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';

@lazySingleton
class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription? _connectionSubscription;

  // Stream для статуса подключения
  final _connectionStateController = StreamController<DeviceConnectionState>.broadcast();
  Stream<DeviceConnectionState> get connectionStateStream => _connectionStateController.stream;

  // Сканирование
  // Stream<DiscoveredDevice> scanForMddDevices() {
  //   return _ble.scanForDevices(
  //     withServices: [Uuid.parse(AppConstants.serviceUuid)],
  //     scanMode: ScanMode.lowLatency,
  //   );
  // }
  Stream<DiscoveredDevice> scanForMddDevices() {
    return _ble.scanForDevices(
      withServices: [], // <-- Оставьте пустым, чтобы видеть ВСЕ устройства
      scanMode: ScanMode.lowLatency,
    );
  }

  // Подключение
  void connectToDevice(String deviceId, Function(List<int>) onDataReceived) {
    _connectionSubscription?.cancel();

    _connectionSubscription = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
      servicesWithCharacteristicsToDiscover: {
        Uuid.parse(AppConstants.serviceUuid): [
          Uuid.parse(AppConstants.sosCharacteristicUuid),
          Uuid.parse(AppConstants.ackCharacteristicUuid),
          Uuid.parse(AppConstants.configCharacteristicUuid), // Добавили конфиг
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

  // Подписка на SOS
  void _subscribeToSos(String deviceId, Function(List<int>) onDataReceived) {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.serviceUuid),
      characteristicId: Uuid.parse(AppConstants.sosCharacteristicUuid),
      deviceId: deviceId,
    );

    _ble.subscribeToCharacteristic(characteristic).listen((data) {
      onDataReceived(data);
    }, onError: (e) {
      print("BLE Subscription Error: $e");
    });
  }

  // Отправка подтверждения (ACK)
  Future<void> writeAck(String deviceId, bool success) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.serviceUuid),
      characteristicId: Uuid.parse(AppConstants.ackCharacteristicUuid),
      deviceId: deviceId,
    );
    final value = success ? [0x01] : [0x00];
    try {
      await _ble.writeCharacteristicWithResponse(characteristic, value: value);
    } catch (e) {
      print("BLE: Failed to send ACK: $e");
    }
  }

  // Запись настроек (ТОЛЬКО BLE)
  Future<void> writeConfig(String deviceId, int sensitivity, int timeout) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(AppConstants.serviceUuid),
      characteristicId: Uuid.parse(AppConstants.configCharacteristicUuid),
      deviceId: deviceId,
    );

    // Простой протокол: [sensitivity (1 byte), timeout (1 byte)]
    // sensitivity: 1-10, timeout: 10-60
    final value = [sensitivity, timeout];

    try {
      await _ble.writeCharacteristicWithResponse(characteristic, value: value);
      print("BLE: Config written: $value");
    } catch (e) {
      print("BLE: Failed to write config: $e");
      throw Exception("Device not connected or unreachable");
    }
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
  }
}