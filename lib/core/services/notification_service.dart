import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

// Топ-левел функция для фона
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

@lazySingleton
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Stream для передачи данных об инциденте в UI (main.dart)
  final _incidentController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incidentStream => _incidentController.stream;

  Future<void> initialize() async {
    // 1. Permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    // 2. Local Notifications Setup
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Обработка нажатия на ЛОКАЛЬНОЕ уведомление (которое мы показали сами)
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _incidentController.add(data); // Отправляем в стрим
          } catch (e) {
            print("Error parsing payload: $e");
          }
        }
      },
    );

    // 3. FCM Handlers
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // А. Приложение открыто (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("FCM Foreground Message: ${message.data}");

      // Показываем уведомление (чтобы был звук/вибрация)
      _showForegroundNotification(message);

      // И СРАЗУ отправляем событие в UI, чтобы открыть экран (если нужно)
      if (message.data.containsKey('event_uid')) {
        _incidentController.add(message.data);
      }
    });

    // Б. Приложение свернуто, клик по уведомлению (Background -> Foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("FCM Notification Clicked (Background): ${message.data}");
      if (message.data.containsKey('event_uid')) {
        _incidentController.add(message.data);
      }
    });
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'SOS Alert!',
      message.notification?.body ?? 'Someone needs help.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // Важно для тревоги
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data), // Кладем данные в payload
    );
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // В. Приложение было закрыто, клик по уведомлению (Terminated -> Foreground)
  Future<Map<String, dynamic>?> getInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      print("FCM Initial Message (Terminated): ${message.data}");
      return message.data;
    }
    return null;
  }
}