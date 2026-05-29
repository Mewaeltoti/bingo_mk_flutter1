import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

import 'core/services/service_locator.dart';
import 'core/theme/app_theme.dart';

import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/bingo_repository.dart';

import 'presentation/blocs/auth_cubit.dart';
import 'presentation/blocs/game_cubit.dart';
import 'presentation/blocs/wallet_cubit.dart';

import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/main_container.dart';
import 'presentation/pages/splash_page.dart';

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
/// MAIN ENTRY
/// ======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST before runApp
  await _initializeApp();

  runApp(const BootstrapApp());
}

/// ======================================================
/// BACKGROUND INITIALIZATION (NON-BLOCKING)
/// ======================================================
Future<void> _initializeApp() async {
  try {
    // ---------------- Firebase ----------------
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // ---------------- Notifications ----------------
    if (!kIsWeb) {
      final FlutterLocalNotificationsPlugin flnp =
          FlutterLocalNotificationsPlugin();

      const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const initSettings = InitializationSettings(
        android: androidInit,
      );

      await flnp.initialize(initSettings);

      const channel = AndroidNotificationChannel(
        'wallet_notifications',
        'Wallet Notifications',
        description: 'Deposit and withdrawal updates',
        importance: Importance.high,
      );

      await flnp
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await FirebaseMessaging.instance.requestPermission();
    }

    // ---------------- Dependency Injection ----------------
    await initServiceLocator();

    debugPrint("✅ App initialized successfully");
  } catch (e, s) {
    debugPrint("❌ Startup initialization failed");
    debugPrint(e.toString());
    debugPrintStack(stackTrace: s);
  }
}

/// ======================================================
/// BOOTSTRAP APP (STARTS UI IMMEDIATELY)
/// ======================================================
class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bingo MK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AppRouter(),
    );
  }
}

/// ======================================================
/// APP ROUTER
/// ======================================================
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _showSplash = true;
  bool _serviceReady = false;

  AuthCubit? _authCubit;
  GameCubit? _gameCubit;
  WalletCubit? _walletCubit;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    // Services are already ready (initialized before runApp)
    _authCubit = AuthCubit(sl<AuthRepository>());
    _serviceReady = true;
  }

  @override
  void dispose() {
    _authCubit?.close();
    _gameCubit?.close();
    _walletCubit?.close();
    super.dispose();
  }

  void _ensureCubits(String userId) {
    if (_lastUserId == userId) return;

    _gameCubit?.close();
    _walletCubit?.close();

    _gameCubit = GameCubit(
      bingoRepository: sl<BingoRepository>(),
      userId: userId,
    );

    _walletCubit = WalletCubit(
      bingoRepository: sl<BingoRepository>(),
      userId: userId,
    );

    _lastUserId = userId;
  }

  @override
  Widget build(BuildContext context) {
    // ---------------- SPLASH ----------------
    if (_showSplash) {
      return SplashPage(
        onFinish: () => setState(() => _showSplash = false),
      );
    }

    // Wait for services to be ready
    if (!_serviceReady || _authCubit == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ---------------- AUTH ROUTING ----------------
    return BlocProvider<AuthCubit>.value(
      value: _authCubit!,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            _ensureCubits(state.userId);
            if (_gameCubit == null || _walletCubit == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return MultiBlocProvider(
              providers: [
                BlocProvider<GameCubit>.value(value: _gameCubit!),
                BlocProvider<WalletCubit>.value(value: _walletCubit!),
              ],
              child: const MainContainer(),
            );
          }

          if (state is AuthLoading || state is AuthInitial) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is AuthUnauthenticated || state is AuthError) {
            return BlocProvider<AuthCubit>.value(
              value: _authCubit!,
              child: const DashboardPage(),
            );
          }

          // Safe fallback
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}