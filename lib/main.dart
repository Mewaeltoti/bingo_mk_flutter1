import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

import 'core/services/service_locator.dart';
import 'core/theme/app_theme.dart';

import 'presentation/blocs/auth_cubit.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/bingo_repository.dart';

import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/pages/main_container.dart';

/// ======================================================
/// BACKGROUND HANDLER
/// ======================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// ======================================================
/// MAIN
/// ======================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const BootstrapApp());

  // Heavy initialization AFTER first frame
  Future.microtask(() async {
    await _initApp();
  });
}

/// ======================================================
/// SAFE INIT (NO UI BLOCKING)
/// ======================================================
Future<void> _initApp() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (!kIsWeb) {
      final flnp = FlutterLocalNotificationsPlugin();

      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings =
          InitializationSettings(android: androidInit);

      await flnp.initialize(initSettings);

      const channel = AndroidNotificationChannel(
        'wallet_notifications',
        'Wallet Notifications',
        description: 'Deposit and withdrawal status updates',
        importance: Importance.high,
      );

      await flnp
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await FirebaseMessaging.instance.requestPermission();
    }

    await initServiceLocator();

    debugPrint("✅ App initialized successfully");
  } catch (e, s) {
    debugPrint("❌ INIT ERROR");
    debugPrint(e.toString());
    debugPrintStack(stackTrace: s);
  }
}