import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';

import 'presentation/blocs/auth_cubit.dart';
import 'presentation/blocs/game_cubit.dart';
import 'presentation/blocs/wallet_cubit.dart';

import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/bingo_repository_impl.dart';

import 'domain/repositories/bingo_repository.dart';

import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/main_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authRepository = AuthRepositoryImpl();
  final bingoRepository = BingoRepositoryImpl();

  runApp(
    BingoApp(
      authRepository: authRepository,
      bingoRepository: bingoRepository,
    ),
  );
}

class BingoApp extends StatelessWidget {
  final AuthRepositoryImpl authRepository;
  final BingoRepository bingoRepository;

  const BingoApp({
    super.key,
    required this.authRepository,
    required this.bingoRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: bingoRepository),
      ],
      child: BlocProvider(
        create: (_) => AuthCubit(authRepository),
        child: MaterialApp(
          title: 'Bingo Ethio',
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
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final bingoRepository =
            RepositoryProvider.of<BingoRepository>(context);

        // =========================
        // 🎮 USER FLOW (MAIN APP)
        // =========================
        if (state is AuthAuthenticated) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => GameCubit(
                  bingoRepository: bingoRepository,
                  userId: state.userId,
                ),
              ),
              BlocProvider(
                create: (_) => WalletCubit(
                  bingoRepository: bingoRepository,
                  userId: state.userId,
                ),
              ),
            ],
            child: const MainContainer(),
          );
        }

        // =========================
        // 🔓 NOT LOGGED IN
        // =========================
        return const DashboardPage();
      },
    );
  }
}