import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'game_page.dart';
import 'payment_page.dart';
import 'profile_page.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/game_cubit.dart';
import '../blocs/wallet_cubit.dart';
import '../widgets/loading_dialog.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}
class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      GamePage(onTabChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const PaymentPage(),
      const ProfilePage(),
    ];

    return MultiBlocListener(
      listeners: [
        BlocListener<GameCubit, GameState>(
          listenWhen: (previous, current) {
            if (previous is! GameLoaded || current is! GameLoaded) return true;
            return previous.isActionLoading != current.isActionLoading;
          },
          listener: (context, state) {
            if (state is GameLoaded &&
                state.isActionLoading &&
                state.status != GameStatus.won) {
              LoadingDialog.show(context);
            } else {
              LoadingDialog.hide(context);
            }
          },
        ),
        BlocListener<WalletCubit, WalletState>(
          listenWhen: (previous, current) {
            if (previous is! WalletLoaded || current is! WalletLoaded) {
              return true;
            }
            return previous.isActionLoading != current.isActionLoading;
          },
          listener: (context, state) {
            if (state is WalletLoaded && state.isActionLoading) {
              LoadingDialog.show(context);
            } else {
              LoadingDialog.hide(context);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: const Border(
              top: BorderSide(color: Colors.white10, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: AppColors.darkCard,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.white38,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_esports_outlined),
                activeIcon: Icon(Icons.sports_esports, color: AppColors.primary),
                label: 'Play Bingo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet, color: AppColors.primary),
                label: 'My Wallet',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
