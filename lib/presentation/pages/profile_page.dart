import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/wallet_cubit.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFF0E1321);
  static const bgDeep      = Color(0xFF090E1C);
  static const surface     = Color(0xFF161B2A);
  static const surfaceHigh = Color(0xFF1A1F2E);
  static const divider     = Color(0xFF303444);

  static const gold        = Color(0xFFF1C100);
  static const goldLight   = Color(0xFFFFE8AE);
  static const goldFill    = Color(0x1AF1C100);
  static const goldBorder  = Color(0x40F1C100);

  static const danger      = Color(0xFFE63946);
  static const dangerFill  = Color(0x1AE63946);
  static const dangerBorder= Color(0x40E63946);

  static const textHigh    = Color(0xFFDEE2F6);
  static const textMid     = Color(0xFFD1C5AB);
  static const textLow     = Color(0xFF9A9078);
}

class _T {
  static TextStyle label({double size = 11, Color? color, double spacing = 0.8, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, letterSpacing: spacing, color: color ?? _C.textMid);
  static TextStyle body({double size = 13, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, color: color ?? _C.textHigh);
}

// ─────────────────────────────────────────────────────────────────────────────
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

    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 28),
              decoration: BoxDecoration(
                color: _C.bgDeep,
                border: Border(
                  bottom: BorderSide(color: _C.divider),
                ),
              ),
              child: Column(children: [
                // Avatar ring
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.goldFill,
                    border: Border.all(color: _C.gold, width: 2),
                    boxShadow: [
                      BoxShadow(color: _C.gold.withOpacity(0.25), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded, size: 38, color: _C.gold),
                ),
                const SizedBox(height: 16),

                // Balance
                BlocBuilder<WalletCubit, WalletState>(
                  builder: (context, state) {
                    final balance = state is WalletLoaded ? state.balance : 0.0;
                    return Column(children: [
                      Text(S.balance, style: _T.label(size: 10, color: _C.textLow, spacing: 2.0)),
                      const SizedBox(height: 4),
                      Text(
                        '${balance.toStringAsFixed(2)} ETB',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _C.gold,
                        ),
                      ),
                    ]);
                  },
                ),
              ]),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section label
                Text(S.account, style: _T.label(size: 10, color: _C.textLow, spacing: 2.0)),
                const SizedBox(height: 10),

                // Phone tile
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _C.goldFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.goldBorder),
                      ),
                      child: const Icon(Icons.phone_android_rounded, color: _C.gold, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(S.phoneNumberLabel, style: _T.label(size: 9, color: _C.textLow, spacing: 1.0)),
                      const SizedBox(height: 3),
                      Text(phone, style: _T.body(size: 15, weight: FontWeight.w800)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 8),

                // Info note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Your phone number is your unique account ID.',
                    style: _T.label(size: 11, color: _C.textLow, spacing: 0.2, weight: FontWeight.w400),
                  ),
                ),

                const SizedBox(height: 32),
                Container(height: 0.5, color: _C.divider),
                const SizedBox(height: 32),

                // Sign out
                GestureDetector(
                  onTap: () => context.read<AuthCubit>().logout(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _C.dangerFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.dangerBorder),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.logout_rounded, color: _C.danger, size: 18),
                      const SizedBox(width: 10),
                      Text(S.signOut, style: _T.label(size: 13, color: _C.danger, spacing: 1.5)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}