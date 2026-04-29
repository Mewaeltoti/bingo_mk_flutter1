import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/auth_cubit.dart';
import 'presentation/blocs/game_cubit.dart';
import 'presentation/blocs/wallet_cubit.dart';
import 'domain/repositories/bingo_repository.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/bingo_repository_impl.dart';
import 'presentation/blocs/admin_cubit.dart';
import 'presentation/pages/dashboard_page.dart';
import 'presentation/pages/main_container.dart';
import 'presentation/pages/admin_page.dart';

import 'core/utils/pre_generated_cards.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PreGeneratedCards.init();

  final authRepository = AuthRepositoryImpl();
  final bingoRepository = BingoRepositoryImpl();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider<BingoRepository>.value(value: bingoRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AuthCubit(authRepository)),
        ],
        child: const BingoApp(),
      ),
    ),
  );
}

class BingoApp extends StatelessWidget {
  const BingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bingo Ethio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            if (state.isAdmin) {
              return BlocProvider(
                create: (context) => AdminCubit(
                  RepositoryProvider.of<BingoRepository>(context),
                ),
                child: const AdminPage(),
              );
            }

            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => GameCubit(
                    bingoRepository: RepositoryProvider.of<BingoRepository>(context),
                    gameId: 'current_game',
                    userId: state.userId,
                  ),
                ),
                BlocProvider(
                  create: (context) => WalletCubit(
                    bingoRepository: RepositoryProvider.of<BingoRepository>(context),
                    userId: state.userId,
                  ),
                ),
              ],
              child: const MainContainer(),
            );
          }
          return const DashboardPage();
        },
      ),
    );
  }
}
