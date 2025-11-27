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
import '../../data/models/sos_payload_model.dart';

@lazySingleton
class AppBackgroundService {
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Настройка уведомлений для Android Foreground Service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mdd_foreground',
      'MDD Watch Service',
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
        notificationChannelId: 'mdd_foreground',
        initialNotificationTitle: 'MDD Companion',
        initialNotificationContent: 'Monitoring active',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
        ],
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

// --- ENTRY POINTS ---

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // 1. Инициализация зависимостей в новом изоляте
  await Hive.initFlutter();
  // Важно: configureDependencies должен быть безопасен для повторного вызова или
  // get_it должен быть сброшен, но в новом изоляте get_it пуст, так что ок.
  await configureDependencies();

  final bleService = getIt<BleService>();
  final sosRepository = getIt<SosRepository>();
  final locationService = getIt<LocationService>();

  // Получаем сохраненный ID устройства (предполагаем, что сохранили его при привязке)
  // Для примера хардкодим или берем из Hive, если бы реализовали DeviceRepository
  // В реальном коде: final deviceId = await deviceRepository.getLinkedDeviceId();
  String? linkedDeviceId;

  // Слушаем команды от UI
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('setDeviceId').listen((event) {
    linkedDeviceId = event?['deviceId'];
    if (linkedDeviceId != null) {
      _startMonitoring(bleService, sosRepository, locationService, linkedDeviceId!);
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

  // Если устройство уже известно (например, передано при старте или сохранено)
  // _startMonitoring(...)
}

void _startMonitoring(
    BleService bleService,
    SosRepository sosRepository,
    LocationService locationService,
    String deviceId,
    ) {
  print("Background Service: Starting monitoring for $deviceId");

  bleService.connectToDevice(deviceId, (data) async {
    print("Background Service: SOS Data Received: $data");

    try {
      // 1. Парсинг данных (Пример: JSON в байтах)
      final jsonString = utf8.decode(data);
      final jsonMap = jsonDecode(jsonString);
      var payload = SosPayloadModel.fromJson(jsonMap);

      // 2. Получение геолокации телефона
      final position = await locationService.getCurrentPosition();
      if (position != null) {
        payload = payload.copyWithLocation(
          lat: position.latitude,
          lon: position.longitude,
          alt: position.altitude,
        );
      }

      // 3. Отправка на сервер
      final result = await sosRepository.sendSosSignal(payload);

      // 4. Подтверждение на часы
      result.fold(
            (failure) {
          print("Background Service: Failed to send SOS: ${failure.message}");
          bleService.writeAck(deviceId, false); // Ошибка
        },
            (success) {
          print("Background Service: SOS sent successfully");
          bleService.writeAck(deviceId, true); // Успех
        },
      );
    } catch (e) {
      print("Background Service: Error processing SOS: $e");
      bleService.writeAck(deviceId, false);
    }
  });
}