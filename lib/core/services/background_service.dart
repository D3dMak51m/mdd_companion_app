import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
        autoStart: false,
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
        autoStart: false,
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
  await configureDependencies();

  final bleService = getIt<BleService>();
  final sosRepository = getIt<SosRepository>();
  final deviceRepository = getIt<DeviceRepository>();
  final locationService = getIt<LocationService>();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String? activeDeviceId;

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
      _startMonitoring(bleService, sosRepository, deviceRepository, locationService, deviceId, flutterLocalNotificationsPlugin);
    }
  });

  // --- НОВЫЙ ОБРАБОТЧИК ДЛЯ ОТПРАВКИ КОНФИГА ---
  service.on('sendInitialConfig').listen((event) async {
    final deviceId = event?['deviceId'];
    final sensitivity = event?['sensitivity'] as int? ?? 5;
    final timeout = event?['timeout'] as int? ?? 30;

    if (deviceId != null) {
      print("Background Service: Sending initial config to $deviceId");
      try {
        // Пытаемся записать конфиг. Если устройство подключено, это сработает.
        await bleService.writeConfig(deviceId, sensitivity, timeout);
        print("Background Service: Config sent successfully");
      } catch (e) {
        print("Background Service: Failed to send config: $e");
      }
    }
  });
  // ---------------------------------------------

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  if (activeDeviceId == null) {
    activeDeviceId = settingsBox.get('active_device_id');
    if (activeDeviceId != null) {
      print("Background Service: Restored device ID: $activeDeviceId");
      _updateNotification(flutterLocalNotificationsPlugin, "Restoring connection...");
      _startMonitoring(bleService, sosRepository, deviceRepository, locationService, activeDeviceId!, flutterLocalNotificationsPlugin);
    } else {
      _updateNotification(flutterLocalNotificationsPlugin, "Idle. No device connected.");
    }
  }
}

void _startMonitoring(
    BleService bleService,
    SosRepository sosRepository,
    DeviceRepository deviceRepository,
    LocationService locationService,
    String deviceId,
    FlutterLocalNotificationsPlugin notifPlugin,
    ) {
  print("Background Service: Starting monitoring loop for $deviceId");

  bleService.connectToDevice(deviceId, (data) async {
    try {
      final jsonString = utf8.decode(data);
      print("Background Service: Raw Data: $jsonString");

      final jsonMap = jsonDecode(jsonString);
      final String msgType = jsonMap['type'] ?? 'SOS';

      if (msgType == 'TRACKING') {
        print("Background Service: TRACKING packet received");
        final position = await locationService.getCurrentPosition();

        if (position != null) {
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
          print("Background Service: Location sent to server");
        }
      } else {
        print("Background Service: SOS packet received");
        _updateNotification(notifPlugin, "SOS RECEIVED! Sending to server...");

        var payload = SosPayloadModel.fromJson(jsonMap);
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          payload = payload.copyWithLocation(
            lat: position.latitude,
            lon: position.longitude,
            alt: position.altitude,
          );
        }

        final result = await sosRepository.sendSosSignal(payload);

        result.fold(
              (failure) {
            print("Background Service: Failed to send SOS: ${failure.message}");
            bleService.writeAck(deviceId, false);
            _updateNotification(notifPlugin, "SOS Send Failed! Check internet.");
          },
              (success) {
            print("Background Service: SOS sent successfully");
            bleService.writeAck(deviceId, true);
            _updateNotification(notifPlugin, "SOS Sent. Help is coming.");
          },
        );
      }
    } catch (e) {
      print("Background Service: Error processing BLE data: $e");
      bleService.writeAck(deviceId, false);
    }
  });

  _updateNotification(notifPlugin, "Monitoring: $deviceId");
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