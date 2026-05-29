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

  // Step 1: Init Firebase (critical — must not fail silently)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Step 2: Init dependency injection
  await initServiceLocator();

  // Step 3: Best-effort extras (notifications, messaging)
  _initExtras();

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
    // ---- SPLASH ----
    if (_showSplash) {
      return SplashPage(
        onFinish: () => setState(() => _showSplash = false),
      );
    }

    // ---- AUTH ROUTING ----
    return BlocProvider<AuthCubit>.value(
      value: _authCubit,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            _ensureCubits(state.userId);
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
            child: const DashboardPage(),
          );
        },
      ),
    );
  }
}
