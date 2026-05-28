import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'core/services/service_locator.dart';

import 'presentation/blocs/auth_cubit.dart';
import 'presentation/blocs/game_cubit.dart';
import 'presentation/blocs/wallet_cubit.dart';

import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/bingo_repository.dart';

import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/main_container.dart';
import 'presentation/pages/splash_page.dart';

/// ======================================================
/// BACKGROUND HANDLER
/// ======================================================
/// Must be top-level and annotated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// ======================================================
/// MAIN
/// ======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    /// --------------------------------------------------
    /// Firebase Init
    /// --------------------------------------------------
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    /// --------------------------------------------------
    /// Firebase Messaging Background Handler
    /// --------------------------------------------------
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    /// --------------------------------------------------
    /// Notifications Setup (Android)
    /// --------------------------------------------------
    if (!kIsWeb) {
      final FlutterLocalNotificationsPlugin flnp =
          FlutterLocalNotificationsPlugin();

      /// Android initialization
      const AndroidInitializationSettings
          initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      /// Global init settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      /// Initialize plugin
      await flnp.initialize(initializationSettings);

      /// Notification channel
      const AndroidNotificationChannel channel =
          AndroidNotificationChannel(
        'wallet_notifications',
        'Wallet Notifications',
        description: 'Deposit and withdrawal status updates',
        importance: Importance.high,
      );

      /// Create notification channel
      await flnp
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      /// Request permissions (Android 13+)
      await FirebaseMessaging.instance.requestPermission();

      debugPrint("Notifications initialized successfully");
    }

    /// --------------------------------------------------
    /// Dependency Injection / Service Locator
    /// --------------------------------------------------
    await initServiceLocator();

    debugPrint("Service locator initialized successfully");

    /// --------------------------------------------------
    /// Run App
    /// --------------------------------------------------
    runApp(const BingoApp());
  } catch (e, s) {
    debugPrint("APP STARTUP CRASH:");
    debugPrint(e.toString());
    debugPrintStack(stackTrace: s);
  }
}

/// ======================================================
/// ROOT APP
/// ======================================================
class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(
          value: sl<AuthRepository>(),
        ),
        RepositoryProvider<BingoRepository>.value(
          value: sl<BingoRepository>(),
        ),
      ],
      child: BlocProvider(
        create: (_) => AuthCubit(sl<AuthRepository>()),
        child: MaterialApp(
          title: 'Bingo MK',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,

          home: const AppRouter(),
        ),
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

  GameCubit? _gameCubit;
  WalletCubit? _walletCubit;

  String? _lastUserId;

  @override
  void dispose() {
    _gameCubit?.close();
    _walletCubit?.close();
    super.dispose();
  }

  /// --------------------------------------------------
  /// Ensure Cubits
  /// --------------------------------------------------
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
    /// --------------------------------------------------
    /// Splash
    /// --------------------------------------------------
    if (_showSplash) {
      return SplashPage(
        onFinish: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }

    /// --------------------------------------------------
    /// Auth Router
    /// --------------------------------------------------
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        /// --------------------------
        /// Authenticated
        /// --------------------------
        if (state is AuthAuthenticated) {
          try {
            _ensureCubits(state.userId);

            if (_gameCubit == null || _walletCubit == null) {
              return const Scaffold(
                body: Center(
                  child: Text("Cubit initialization failed"),
                ),
              );
            }

            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: _gameCubit!),
                BlocProvider.value(value: _walletCubit!),
              ],
              child: const MainContainer(),
            );
          } catch (e, s) {
            debugPrint("Cubit creation failed:");
            debugPrint(e.toString());
            debugPrintStack(stackTrace: s);

            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  "Startup Error:\n$e",
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
        }

        /// --------------------------
        /// Loading
        /// --------------------------
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.secondary,
              ),
            ),
          );
        }

        /// --------------------------
        /// Logged Out
        /// --------------------------
        return const DashboardPage();
      },
    );
  }
}