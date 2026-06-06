import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/wallet_cubit.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';
import 'package:bingo_mk/core/theme/app_tokens.dart';



class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final phone = email.contains('@')
        ? email.split('@').first
        : (user?.phoneNumber ?? 'Unknown');

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, _) => Scaffold(
      backgroundColor: AppTokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTokens.goldAltFill,
                  border: Border.all(color: AppTokens.goldAlt, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: AppTokens.goldAlt.withOpacity(0.12), blurRadius: 16),
                  ],
                ),
                child: const Icon(Icons.person_outline_rounded, size: 32, color: AppTokens.goldAlt),
              ),
              const SizedBox(height: 16),
              
              // Phone
              Text(
                phone,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTokens.textHigh,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: Mobile Account',
                style: AppText.label(size: 11, color: AppTokens.textLow),
              ),
              const Spacer(),

              // Wallet Balance Card
              BlocBuilder<WalletCubit, WalletState>(
                builder: (context, state) {
                  final balance = state is WalletLoaded ? state.balance : 0.0;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTokens.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTokens.divider, width: 0.75),
                    ),
                    child: Column(
                      children: [
                        Text(S.availableBalance, style: AppText.label(size: 10, color: AppTokens.textLow, spacing: 0.5)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              balance.toStringAsFixed(2),
                              style: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppTokens.goldAlt,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('ETB', style: AppText.label(size: 11, color: AppTokens.goldAlt)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Sign out button
              GestureDetector(
                onTap: () => context.read<AuthCubit>().logout(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTokens.dangerFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTokens.dangerBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: AppTokens.danger, size: 16),
                      const SizedBox(width: 8),
                      Text(S.signOut, style: AppText.label(size: 12, color: AppTokens.danger, spacing: 1.0)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
    );
  }
}