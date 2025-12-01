import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/services/notification_service.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/incident_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'firebase_options.dart'; // Сгенерирован через flutterfire configure

// Глобальный ключ для навигации без контекста (для уведомлений)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Перехват глобальных ошибок
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Инициализация Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Инициализация Hive (Локальная БД)
    await Hive.initFlutter();
    await Hive.openBox(AppConstants.settingsBoxName);

    // 3. Инициализация DI (GetIt)
    await configureDependencies();

    // 4. Настройка уведомлений (Push & Local)
    final notificationService = getIt<NotificationService>();

    // Инициализируем сервис и подписываемся на стрим событий
    await notificationService.initialize();

    // 5. Проверка, было ли приложение открыто из уведомления (Cold Start)
    final initialData = await notificationService.getInitialMessage();

    runApp(MddCompanionApp(initialData: initialData));
  }, (error, stack) {
    print("Global Error: $error");
    print(stack);
  });
}

class MddCompanionApp extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const MddCompanionApp({super.key, this.initialData});

  @override
  State<MddCompanionApp> createState() => _MddCompanionAppState();
}

class _MddCompanionAppState extends State<MddCompanionApp> {
  late StreamSubscription _incidentSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Обработка Cold Start (если открыли из убитого состояния)
    if (widget.initialData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationData(widget.initialData!);
      });
    }

    // 2. Подписка на поток инцидентов (Foreground & Background Resume)
    final notificationService = getIt<NotificationService>();
    _incidentSubscription = notificationService.incidentStream.listen((data) {
      _handleNotificationData(data);
    });
  }

  @override
  void dispose() {
    _incidentSubscription.cancel();
    super.dispose();
  }

  /// Логика обработки данных из уведомления
  void _handleNotificationData(Map<String, dynamic> data) {
    print("Handling Notification Data: $data");

    // Согласно документации бэкенда, в data приходит sos_event_uid
    if (data.containsKey('sos_event_uid')) {
      final String incidentId = data['sos_event_uid'];

      // Переходим на экран инцидента, передавая только ID
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => IncidentScreen(incidentId: incidentId),
        ),
      );
    } else {
      print("Notification data missing 'sos_event_uid'");
    }
  }

  @override
  Widget build(BuildContext context) {
    // AuthBloc нужен глобально, чтобы проверять состояние входа
    return BlocProvider(
      create: (context) => getIt<AuthBloc>()..add(AuthCheckRequested()),
      child: MaterialApp(
        navigatorKey: navigatorKey, // <--- ВАЖНО
        title: 'MDD Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
        ),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            // Роутинг на основе состояния авторизации
            if (state.status == AuthStatus.authenticated) {
              return const HomeScreen();
            } else if (state.status == AuthStatus.loading) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}