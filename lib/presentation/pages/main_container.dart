import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'game_page.dart';
import 'payment_page.dart';
import 'leaderboard_page.dart';
import 'profile_page.dart';
import 'admin_page.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/auth_cubit.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final bool isAdmin = state is AuthAuthenticated && state.isAdmin;

        final List<Widget> pages = isAdmin
            ? [
                const AdminPage(),
                const GamePage(),
                const ProfilePage(),
              ]
            : [
                const GamePage(),
                const PaymentPage(),
                const LeaderboardPage(),
                const ProfilePage(),
              ];

        final List<Map<String, dynamic>> items = isAdmin
            ? [
                {'icon': Icons.security, 'label': 'Admin'},
                {'icon': Icons.gamepad, 'label': 'Game'},
                {'icon': Icons.person, 'label': 'Profile'},
              ]
            : [
                {'icon': Icons.gamepad, 'label': 'Game'},
                {'icon': Icons.account_balance_wallet, 'label': 'Wallet'},
                {'icon': Icons.emoji_events, 'label': 'Ranks'},
                {'icon': Icons.person, 'label': 'Profile'},
              ];

        if (_currentIndex >= pages.length) _currentIndex = 0;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    return _buildNavItem(index, items[index]['icon'], items[index]['label']);
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
