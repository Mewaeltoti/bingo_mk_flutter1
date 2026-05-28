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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color unselectedColor = isDark ? Colors.white60 : Colors.black54;
    final Color selectedColor   = isDark ? AppColors.secondary : AppColors.primary;
    final Color navBg           = isDark ? AppColors.darkCard   : Colors.white;

    final List<Widget> pages = [
      GamePage(onTabChanged: (index) {
        setState(() => _currentIndex = index);
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
            if (previous is! WalletLoaded || current is! WalletLoaded) return true;
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
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: navBg,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: navBg,
            selectedItemColor: selectedColor,
            unselectedItemColor: unselectedColor,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_esports_outlined, color: unselectedColor),
                activeIcon: Icon(Icons.sports_esports, color: selectedColor),
                label: 'Play',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined, color: unselectedColor),
                activeIcon: Icon(Icons.account_balance_wallet, color: selectedColor),
                label: 'Wallet',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline, color: unselectedColor),
                activeIcon: Icon(Icons.person, color: selectedColor),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}