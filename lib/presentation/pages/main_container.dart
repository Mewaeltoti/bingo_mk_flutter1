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
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final List<Widget> pages = [
            const GamePage(),
            const PaymentPage(),
            const ProfilePage(),
          ];

          final List<Map<String, dynamic>> items = [
            {'icon': Icons.gamepad, 'label': 'Game'},
            {'icon': Icons.account_balance_wallet, 'label': 'Wallet'},
            {'icon': Icons.person, 'label': 'Profile'},
          ];

          if (_currentIndex >= pages.length) _currentIndex = 0;

          return Scaffold(
            body: IndexedStack(index: _currentIndex, children: pages),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        color: Colors.black.withOpacity(0.08),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      items.length,
                      (index) => _buildNavItem(
                        index,
                        items[index]['icon'],
                        items[index]['label'],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = _currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
