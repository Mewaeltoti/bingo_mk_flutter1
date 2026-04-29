import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/wallet_cubit.dart';
import 'payment_page.dart';
import '../../core/theme/app_theme.dart';
import 'game_page.dart';
import 'login_page.dart';
import 'signup_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHero(),
                const SizedBox(height: 48),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
            children: [
              TextSpan(
                text: 'BINGO ',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: 'ETHIO',
                style: TextStyle(color: AppColors.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Play. Win. Celebrate.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return Column(
            children: [
              _buildBigButton(
                label: 'PLAY NOW',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GamePage()),
                  );
                },
                isPrimary: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallButton(
                      label: 'Wallet',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<WalletCubit>(),
                              child: const PaymentPage(),
                            ),
                          ),
                        );
                      },
                      color: AppColors.card,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallButton(
                      label: 'Logout',
                      onPressed: () => context.read<AuthCubit>().logout(),
                      color: Colors.redAccent.withOpacity(0.1),
                      textColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildBigButton(
              label: 'SIGN IN',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _buildBigButton(
              label: 'SIGN UP',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
              isPrimary: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBigButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPrimary
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primary],
              )
            : null,
        color: !isPrimary ? AppColors.secondary.withOpacity(0.2) : null,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: isPrimary ? Colors.black : AppColors.secondary,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            if (isPrimary) const SizedBox(width: 8),
            if (isPrimary) const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    Color? textColor,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor ?? AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
