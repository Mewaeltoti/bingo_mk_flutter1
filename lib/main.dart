import 'package:flutter/foundation.dart' show kIsWeb;
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

// Must be a top-level function (outside main)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Android notification channel — not applicable on web
  if (!kIsWeb) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'wallet_notifications',
      'Wallet Notifications',
      description: 'Deposit and withdrawal status updates',
      importance: Importance.high,
    );
    final flnp = FlutterLocalNotificationsPlugin();
    await flnp
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await initServiceLocator();

  runApp(const BingoApp());
}

class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: sl<AuthRepository>()),
        RepositoryProvider<BingoRepository>.value(value: sl<BingoRepository>()),
      ],
      child: BlocProvider(
        create: (_) => AuthCubit(sl<AuthRepository>()),
        child: MaterialApp(
          title: 'Bingo MK',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const AppRouter(),
        ),
      ),
    );
  }
}

/// ============================
/// 🔥 CLEAN ROUTING LAYER
/// ============================
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
    if (_showSplash) {
      return SplashPage(
        onFinish: () => setState(() => _showSplash = false),
      );
    }

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          _ensureCubits(state.userId);
          return MultiBlocProvider(
            providers: [
              BlocProvider.value(value: _gameCubit!),
              BlocProvider.value(value: _walletCubit!),
            ],
            child: const MainContainer(),
          );
        }

        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            ),
          );
        }

        return const DashboardPage();
      },
    );
  }
}