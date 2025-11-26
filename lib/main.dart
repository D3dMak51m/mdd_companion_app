import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/services/notification_service.dart';
import 'data/models/incident_model.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/incident_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'firebase_options.dart'; // Сгенерирован через flutterfire configure

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Init Hive & DI
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.settingsBoxName);
  await configureDependencies();

  // 3. Init Notifications
  final notificationService = getIt<NotificationService>();
  await notificationService.initialize((data) {
    _handleNotificationTap(data);
  });

  // 4. Check for initial message (Cold start from notification)
  final initialData = await notificationService.getInitialMessage();

  runApp(MddCompanionApp(initialData: initialData));
}

void _handleNotificationTap(Map<String, dynamic> data) {
  if (data.containsKey('event_uid')) {
    try {
      final incident = IncidentModel.fromFcmData(data);
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => IncidentScreen(incident: incident)),
      );
    } catch (e) {
      print("Error parsing incident data: $e");
    }
  }
}

class MddCompanionApp extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const MddCompanionApp({super.key, this.initialData});

  @override
  State<MddCompanionApp> createState() => _MddCompanionAppState();
}

class _MddCompanionAppState extends State<MddCompanionApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      // Небольшая задержка, чтобы контекст навигатора успел построиться
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(widget.initialData!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthBloc>()..add(AuthCheckRequested()),
      child: MaterialApp(
        navigatorKey: navigatorKey, // Важно для навигации без контекста
        title: 'MDD Companion',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state.status == AuthStatus.authenticated) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}