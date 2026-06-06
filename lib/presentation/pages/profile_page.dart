import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/wallet_cubit.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';

class _C {
  static bool get _l => SettingsCubit.isLightModeGlobal;

  static Color get bg          => _l ? const Color(0xFFF2F4F7) : const Color(0xFF050D1A);
  static Color get card        => _l ? const Color(0xFFFFFFFF) : const Color(0xFF0D1B2A);
  static Color get divider     => _l ? const Color(0xFFEAECF0) : const Color(0xFF1C2E40);
  static const gold        = Color(0xFFD4AF37);
  static const goldLight   = Color(0xFFFFE8AE);
  static const goldFill    = Color(0x1AD4AF37);
  static const goldBorder  = Color(0x40D4AF37);
  static const danger      = Color(0xFFE63946);
  static const dangerFill  = Color(0x1AE63946);
  static const dangerBorder= Color(0x40E63946);
  static Color get textHigh => _l ? const Color(0xFF101828) : Colors.white;
  static Color get textLow  => _l ? const Color(0xFF667085) : const Color(0xFF607D8B);
}

class _T {
  static TextStyle label({double size = 11, Color? color, double spacing = 0.8}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: FontWeight.w600, letterSpacing: spacing, color: color ?? _C.textLow);
  static TextStyle body({double size = 13, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, color: color ?? _C.textHigh);
}

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
      backgroundColor: _C.bg,
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
                  color: _C.goldFill,
                  border: Border.all(color: _C.gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: _C.gold.withOpacity(0.12), blurRadius: 16),
                  ],
                ),
                child: const Icon(Icons.person_outline_rounded, size: 32, color: _C.gold),
              ),
              const SizedBox(height: 16),
              
              // Phone
              Text(
                phone,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _C.textHigh,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: Mobile Account',
                style: _T.label(size: 11, color: _C.textLow),
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
                      color: _C.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.divider, width: 0.75),
                    ),
                    child: Column(
                      children: [
                        Text(S.availableBalance, style: _T.label(size: 10, color: _C.textLow, spacing: 0.5)),
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
                                color: _C.gold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('ETB', style: _T.label(size: 11, color: _C.gold)),
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
                    color: _C.dangerFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.dangerBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: _C.danger, size: 16),
                      const SizedBox(width: 8),
                      Text(S.signOut, style: _T.label(size: 12, color: _C.danger, spacing: 1.0)),
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