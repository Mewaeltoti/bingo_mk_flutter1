import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

          // 🌙 DARK MODE ENABLED
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

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashPage(
        onFinish: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => GameCubit(
                  bingoRepository: sl<BingoRepository>(),
                  userId: state.userId,
                ),
              ),
              BlocProvider(
                create: (_) => WalletCubit(
                  bingoRepository: sl<BingoRepository>(),
                  userId: state.userId,
                ),
              ),
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
