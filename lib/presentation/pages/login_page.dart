import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_cubit.dart';
import '../widgets/loading_dialog.dart';
import 'signup_page.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible     = false;

  late AnimationController _animController;
  late Animation<double>   _cardFade;
  late Animation<Offset>   _cardSlide;

  // ── Design tokens (from Stitch Elite Gaming Dark Luxury) ────────────────
  static const _bgColor        = Color(0xFF0E1321);
  static const _cardBg         = Color(0xFF141B2D); // glass panel base
  static const _inputBg        = Color(0xFF090E1C); // surface-container-lowest
  static const _goldPrimary    = Color(0xFFF9C80E); // primary-container
  static const _goldLight      = Color(0xFFFFE8AE); // primary
  static const _goldDark       = Color(0xFF6B5400); // on-primary-container
  static const _electricBlue   = Color(0xFFADC6FF); // secondary
  static const _textPrimary    = Color(0xFFDEE2F6); // on-surface
  static const _textMuted      = Color(0xFFD1C5AB); // on-surface-variant
  static const _borderDefault  = Color(0x1AFFFFFF); // white 10%
  static const _outlineVariant = Color(0xFF4E4632);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardFade = CurvedAnimation(
        parent: _animController, curve: Curves.easeIn);
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          (prev is AuthLoading) != (curr is AuthLoading) ||
          curr is AuthError ||
          curr is AuthAuthenticated,
      listener: (context, state) {
        if (state is AuthLoading) {
          LoadingDialog.show(context);
        } else {
          LoadingDialog.hide(context);
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: const Color(0xFF93000A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        }
        if (state is AuthAuthenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            // ── Ambient glow blobs ──────────────────────────────────────
            Positioned(
              top: -80,
              left: -80,
              child: _glowBlob(const Color(0xFFF9C80E), 0.04, 280),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: _glowBlob(const Color(0xFF006BE3), 0.04, 280),
            ),

            // ── Scrollable content ──────────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 32),
                  child: Column(
                    children: [
                      // Logo
                      _buildLogo(),
                      const SizedBox(height: 32),

                      // Glass card
                      FadeTransition(
                        opacity: _cardFade,
                        child: SlideTransition(
                          position: _cardSlide,
                          child: _buildGlassCard(context),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign up link
                      _buildSignUpLink(context),
                    ],
                  ),
                ),
              ),
            ),

            // ── VIP watermark ────────────────────────────────────────────
            Positioned(
              bottom: 16,
              right: 20,
              child: Opacity(
                opacity: 0.18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(S.vip,
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 32,
                          color: _textPrimary,
                          letterSpacing: 4,
                        )),
                    Text(S.accessOnly,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: 2,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo section ──────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        const Text(
          S.bingo + ' MK',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 52,
            color: _goldLight,
            letterSpacing: 8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          S.premiumGamingSuite,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textMuted,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  // ── Glass card ────────────────────────────────────────────────────────────
  Widget _buildGlassCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(S.welcomeBack,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              )),
          const SizedBox(height: 4),
          Text(S.accessAccount,
              style: TextStyle(
                color: _textMuted.withOpacity(0.8),
                fontSize: 14,
              )),
          const SizedBox(height: 24),

          // Phone field
          _buildFieldLabel(S.phoneNumber),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _phoneController,
            hint: '+251 912 000 000',
            icon: Icons.smartphone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Password field
          _buildFieldLabel('Password'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hint: S.passwordHint,
            icon: Icons.lock_outline,
            isPassword: true,
          ),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(S.forgotPassword,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _goldLight,
                  )),
            ),
          ),
          const SizedBox(height: 16),

          // Sign in button
          _buildSignInButton(context),
          const SizedBox(height: 20),

          // Divider
          Row(children: [
            const Expanded(
                child: Divider(color: Color(0x0DFFFFFF), thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(S.or,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _outlineVariant,
                    letterSpacing: 1,
                  )),
            ),
            const Expanded(
                child: Divider(color: Color(0x0DFFFFFF), thickness: 1)),
          ]),
          const SizedBox(height: 20),

          // Alt login buttons
          Row(children: [
            Expanded(child: _buildAltButton(
              icon: Icons.fingerprint,
              label: S.biometrics,
              onTap: () {},
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildAltButton(
              icon: Icons.vpn_key_outlined,
              label: S.passkey,
              onTap: () {},
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textMuted,
          letterSpacing: 0.3,
        ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_passwordVisible,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _outlineVariant, fontSize: 14),
        prefixIcon: Icon(icon, color: _textMuted, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              )
            : null,
        filled: true,
        fillColor: _inputBg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _goldPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _goldPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _goldPrimary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            context.read<AuthCubit>().login(
              _phoneController.text.trim(),
              _passwordController.text,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            S.signIn,
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _goldDark,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAltButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: _borderDefault),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _textMuted, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.noAccount,
            style: TextStyle(
              color: _textMuted.withOpacity(0.8),
              fontSize: 14,
            )),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<AuthCubit>(),
                  child: const SignupPage(),
                ),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(S.signUpNow,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _electricBlue,
              )),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _glowBlob(Color color, double opacity, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}