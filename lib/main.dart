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
import 'presentation/blocs/settings_cubit.dart';

import 'presentation/pages/login_page.dart';
import 'presentation/pages/main_container.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/pages/pin_lock_page.dart';
import 'core/services/connectivity_service.dart';
import 'presentation/widgets/connectivity_banner.dart';

/// ======================================================
/// BACKGROUND HANDLER
/// ======================================================
Future<void> _showLocalNotification(RemoteMessage message) async {
  if (kIsWeb) return;

  String? title = message.notification?.title;
  String? body = message.notification?.body;

  // Fallback to data payload keys if notification block is empty
  if (title == null && body == null && message.data.isNotEmpty) {
    title = message.data['title'] ?? message.data['notification_title'];
    body = message.data['body'] ?? message.data['notification_body'];
  }

  if (title != null && body != null) {
    final flnp = FlutterLocalNotificationsPlugin();
    await flnp.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'wallet_notifications',
          'Wallet Notifications',
          channelDescription: 'Deposit and withdrawal updates',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _showLocalNotification(message);
}

/// ======================================================
/// MAIN ENTRY
/// ======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Init Firebase (critical — must not fail silently)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Step 2: Init dependency injection
  await initServiceLocator();

  // Step 3: Best-effort extras (notifications, messaging)
  _initExtras();

  ConnectivityService.instance.init();
  runApp(const BootstrapApp());
}

/// Non-critical initialization — failures here won't crash the app
void _initExtras() {
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (!kIsWeb) {
      final flnp = FlutterLocalNotificationsPlugin();

      flnp.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      flnp
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'wallet_notifications',
              'Wallet Notifications',
              description: 'Deposit and withdrawal updates',
              importance: Importance.high,
            ),
          );

      FirebaseMessaging.instance.requestPermission();

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((message) {
        _showLocalNotification(message);
      });
    }
  } catch (e) {
    debugPrint('Non-critical init error: $e');
  }
}

/// ======================================================
/// BOOTSTRAP APP
/// ======================================================
class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp(
            title: 'Bingo MK',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.isLightMode ? ThemeMode.light : ThemeMode.dark,
            builder: (context, child) => ConnectivityBanner(child: child ?? const SizedBox.shrink()),
            home: const AppRouter(),
          );
        },
      ),
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
  bool _isPinVerified = false;
  bool _wasUnauthenticated = false;

  late final AuthCubit _authCubit;
  GameCubit? _gameCubit;
  WalletCubit? _walletCubit;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    // sl is fully ready — Firebase and DI are done before runApp
    _authCubit = AuthCubit(sl<AuthRepository>());
  }

  @override
  void dispose() {
    _authCubit.close();
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
    // We build the actual app structure underneath the splash screen.
    // This allows AuthCubit, GameCubit, and WalletCubit to initialize,
    // fetch user data, and connect to Firestore while the splash animation plays.
    final Widget appBody = BlocProvider<AuthCubit>.value(
      value: _authCubit,
      child: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            setState(() {
              _wasUnauthenticated = true;
              _isPinVerified = false;
            });
          } else if (state is AuthAuthenticated) {
            if (_wasUnauthenticated) {
              setState(() {
                _isPinVerified = true;
                _wasUnauthenticated = false;
              });
            }
          }
        },
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            _ensureCubits(state.userId);

            if (!_isPinVerified) {
              return PinLockPage(
                userId: state.userId,
                onVerified: () {
                  setState(() => _isPinVerified = true);
                },
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
              backgroundColor: Color(0xFF050D1A),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // AuthUnauthenticated or AuthError → show login/dashboard
          return BlocProvider<AuthCubit>.value(
            value: _authCubit,
            child: const LoginPage(),
          );
        },
      ),
    );

    return Stack(
      children: [
        appBody,
        if (_showSplash)
          Positioned.fill(
            child: SplashPage(
              onFinish: () => setState(() => _showSplash = false),
            ),
          ),
      ],
    );
  }
}
