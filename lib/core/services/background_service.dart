import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';
import '../di/injection.dart';
import 'ble_service.dart';
import 'location_service.dart';
import '../../domain/repositories/sos_repository.dart';
import '../../domain/repositories/device_repository.dart';
import '../../data/models/sos_payload_model.dart';
import '../../data/models/location_payload_model.dart';

@lazySingleton
class AppBackgroundService {
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mdd_foreground',
      'MDD Companion Service',
      description: 'Monitoring connection with MDD Watch',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true, // Автостарт включен
        isForegroundMode: true,
        foregroundServiceTypes: [
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
        ],
        notificationChannelId: 'mdd_foreground',
        initialNotificationTitle: 'MDD Companion',
        initialNotificationContent: 'Service initialized',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startService() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  final settingsBox = await Hive.openBox(AppConstants.settingsBoxName);

  // Инициализация DI
  await configureDependencies();

  final bleService = getIt<BleService>();
  final sosRepository = getIt<SosRepository>();
  final deviceRepository = getIt<DeviceRepository>();
  final locationService = getIt<LocationService>();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String? activeDeviceId;

  // --- Обработчики команд ---

  service.on('stopService').listen((event) {
    bleService.disconnect();
    service.stopSelf();
  });

  service.on('setDeviceId').listen((event) {
    final deviceId = event?['deviceId'];
    print("Background Service: Received setDeviceId command: $deviceId");

    if (deviceId != null) {
      activeDeviceId = deviceId;
      settingsBox.put('active_device_id', deviceId);
      _updateNotification(flutterLocalNotificationsPlugin, "Connecting to $deviceId...");
      _startMonitoring(bleService, sosRepository, deviceRepository, locationService, deviceId, flutterLocalNotificationsPlugin, settingsBox, service);
    }
  });

  service.on('sendInitialConfig').listen((event) async {
    final deviceId = event?['deviceId'];
    final sensitivity = event?['sensitivity'] as int? ?? 5;
    final timeout = event?['timeout'] as int? ?? 30;

    if (deviceId != null) {
      try {
        await bleService.writeConfig(deviceId, sensitivity, timeout);
      } catch (e) {
        print("Background Service: Failed to send config: $e");
      }
    }
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // --- АВТО-ПОДКЛЮЧЕНИЕ ПРИ СТАРТЕ ---

  await Future.delayed(const Duration(seconds: 3));

  if (activeDeviceId == null) {
    activeDeviceId = settingsBox.get('active_device_id');
  }

  if (activeDeviceId != null) {
    print("Background Service: Found saved device ID: $activeDeviceId. Auto-connecting...");
    _updateNotification(flutterLocalNotificationsPlugin, "Restoring connection...");
    _startMonitoring(bleService, sosRepository, deviceRepository, locationService, activeDeviceId!, flutterLocalNotificationsPlugin, settingsBox, service);
  } else {
    print("Background Service: No saved device ID. Waiting for pairing.");
    _updateNotification(flutterLocalNotificationsPlugin, "Idle. No device connected.");
  }
}

void _startMonitoring(
    BleService bleService,
    SosRepository sosRepository,
    DeviceRepository deviceRepository,
    LocationService locationService,
    String deviceId,
    FlutterLocalNotificationsPlugin notifPlugin,
    Box settingsBox,
    ServiceInstance service,
    ) {
  // Отключаемся от предыдущих, если были
  bleService.disconnect();

  print("Background Service: Starting monitoring loop for $deviceId");

  // Подписываемся на статус подключения, чтобы уведомить UI
  bleService.connectionStateStream.listen((state) {
    final isConnected = state == DeviceConnectionState.connected;
    // Отправляем событие в UI для обновления статуса
    service.invoke('connectionUpdate', {
      'isConnected': isConnected,
      'deviceId': deviceId,
    });

    if (isConnected) {
      _updateNotification(notifPlugin, "Connected to $deviceId");
    } else if (state == DeviceConnectionState.disconnected) {
      _updateNotification(notifPlugin, "Disconnected. Reconnecting...");
    }
  });

  bleService.connectToDevice(deviceId, (data) async {
    try {
      final jsonString = utf8.decode(data);
      print("Background Service: Raw Data: $jsonString");

      Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      // Добавляем ID устройства
      jsonMap['device_uid'] = deviceId;
      if (jsonMap.containsKey('type') && !jsonMap.containsKey('detected_type')) {
        jsonMap['detected_type'] = jsonMap['type'];
      }

      final String msgType = jsonMap['detected_type'] ?? jsonMap['type'] ?? 'SOS';

      // --- ЛОГИКА ТРЕКИНГА ---
      if (msgType == 'TRACKING') {
        print("Background Service: TRACKING packet received");

        final position = await locationService.getCurrentPosition();

        if (position != null) {
          // 1. Сохраняем координаты в кэш на случай SOS без GPS
          await settingsBox.put('last_lat', position.latitude);
          await settingsBox.put('last_lon', position.longitude);
          print("Background Service: Location cached locally");

          // 2. Отправляем на сервер
          final locationPayload = LocationPayloadModel(
            lat: position.latitude,
            lon: position.longitude,
            speed: position.speed,
            direction: position.heading,
            batteryLevel: jsonMap['battery'] as int?,
            status: 'ONLINE',
            timestamp: DateTime.now().toUtc().toIso8601String(),
          );
          await deviceRepository.sendLocationUpdate(deviceId, locationPayload);
        } else {
          print("Background Service: Could not get GPS for tracking");
        }
      }

      // --- ЛОГИКА SOS ---
      else {
        print("Background Service: SOS packet received");
        _updateNotification(notifPlugin, "SOS RECEIVED! Sending to server...");

        // 1. Подготовка данных
        jsonMap['device_uid'] = deviceId;
        if (jsonMap.containsKey('type') && !jsonMap.containsKey('detected_type')) {
          jsonMap['detected_type'] = jsonMap['type'];
        }
        if (!jsonMap.containsKey('raw_payload')) {
          jsonMap['raw_payload'] = {"info": "Generated by Companion App"};
        }
        if (jsonMap.containsKey('timestamp')) {
          try {
            final date = DateTime.parse(jsonMap['timestamp']);
            jsonMap['timestamp'] = date.toUtc().toIso8601String();
          } catch (_) {}
        }

        // 2. Создаем модель
        var payload = SosPayloadModel.fromJson(jsonMap);

        // 3. Обогащаем GPS
        double? lat;
        double? lon;
        double? alt;

        var position = await locationService.getCurrentPosition();
        if (position == null) {
          print("Background Service: Current GPS failed, trying Last Known...");
          position = await locationService.getLastKnownPosition();
        }

        if (position != null) {
          lat = position.latitude;
          lon = position.longitude;
          alt = position.altitude;
        } else {
          print("Background Service: OS Location failed, trying Hive Cache...");
          lat = settingsBox.get('last_lat');
          lon = settingsBox.get('last_lon');
          alt = 0.0;
        }

        if (lat == null || lon == null) {
          print("Background Service: NO LOCATION! Sending 0.0 fallback.");
          lat = 0.0;
          lon = 0.0;
          alt = 0.0;
        }

        payload = payload.copyWithLocation(lat: lat, lon: lon, alt: alt);

        // 4. Отправляем на сервер
        final result = await sosRepository.sendSosSignal(payload);

        result.fold(
              (failure) {
            print("Background Service: Failed to send SOS: ${failure.message}");
            bleService.writeAck(deviceId, false);
            _updateNotification(notifPlugin, "SOS Send Failed! Server Error.");
          },
              (success) {
            print("Background Service: SOS sent successfully");
            bleService.writeAck(deviceId, true);
            _updateNotification(notifPlugin, "SOS Sent. Help is coming.");
          },
        );
      }
    } catch (e, stack) {
      print("Background Service: Error processing BLE data: $e");
      print(stack);
      bleService.writeAck(deviceId, false);
    }
  });
}

void _updateNotification(FlutterLocalNotificationsPlugin plugin, String content) {
  plugin.show(
    888,
    'MDD Companion',
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'mdd_foreground',
        'MDD Companion Service',
        icon: '@mipmap/ic_launcher',
        ongoing: true,
        importance: Importance.low,
      ),
    ),
  );
}