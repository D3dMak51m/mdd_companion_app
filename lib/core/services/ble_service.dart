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
  void connectToDevice(String deviceId, Function(List<int>) onDataReceived) async {
    // Отменяем предыдущую подписку
    await _connectionSubscription?.cancel();

    // Очистка кэша
    try { await _ble.clearGattCache(deviceId); } catch (_) {}

    print("BLE: Connecting to $deviceId...");

    _connectionSubscription = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10), // Таймаут на одну попытку
      servicesWithCharacteristicsToDiscover: null,
    ).listen((state) async {
      _connectionStateController.add(state.connectionState);

      if (state.connectionState == DeviceConnectionState.connected) {
        print("BLE: Connected to $deviceId");

        // Discovery & MTU
        try {
          await _ble.discoverServices(deviceId);
          await Future.delayed(const Duration(seconds: 1));
          await _ble.requestMtu(deviceId: deviceId, mtu: 250);
        } catch (e) {
          print("BLE: Setup error: $e");
        }

        _subscribeToSos(deviceId, onDataReceived);
      }

      else if (state.connectionState == DeviceConnectionState.disconnected) {
        print("BLE: Disconnected. Retrying in 5 seconds...");
        // ВАЖНО: Библиотека сама не реконнектится, если стрим закрылся.
        // Но connectToDevice возвращает стрим, который не закрывается при ошибке соединения,
        // он просто шлет disconnected.
        // Однако, если произошла ошибка (onError), стрим умрет.
      }
    }, onError: (e) {
      print("BLE Connection Stream Error: $e");
      // Если стрим упал с ошибкой, пробуем перезапустить подключение через паузу
      Future.delayed(const Duration(seconds: 5), () {
        connectToDevice(deviceId, onDataReceived);
      });
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