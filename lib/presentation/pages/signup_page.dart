import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_cubit.dart';
import '../widgets/loading_dialog.dart';
import '../../core/theme/app_theme.dart';

// ─── Design tokens (shared with payment_page) ────────────────────────────────
class _C {
  static const bg         = Color(0xFF050D1A);
  static const card       = Color(0xFF0D1B2A);
  static const cardHigh   = Color(0xFF112236);
  static const divider    = Color(0xFF1C2E40);
  static const gold       = Color(0xFFD4AF37);
  static const goldDim    = Color(0xFFA07C1E);
  static const goldFill   = Color(0x1AD4AF37);
  static const goldBorder = Color(0x40D4AF37);
  static const blue       = Color(0xFF1A237E);
  static const blueMid    = Color(0xFF283593);
  static const accent     = Color(0xFF42A5F5);
  static const success    = Color(0xFF2A9D8F);
  static const danger     = Color(0xFFE63946);
  static const textHigh   = Colors.white;
  static const textMid    = Color(0xFFB0BEC5);
  static const textLow    = Color(0xFF607D8B);
}

class _T {
  static TextStyle label({double size = 11, Color? color, double spacing = 0.8}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size,
          fontWeight: FontWeight.w600, letterSpacing: spacing,
          color: color ?? _C.textMid);
  static TextStyle body({double size = 14, Color? color,
      FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size,
          fontWeight: weight, color: color ?? _C.textHigh);
  static const mono = TextStyle(fontFamily: 'Orbitron');
}

// ─────────────────────────────────────────────────────────────────────────────
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _agreedToTerms   = false;
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;

  // Inline validation
  String? _phoneError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ─── Validation helpers ──────────────────────────────────────────────────
  void _validatePhone(String v) {
    setState(() {
      if (v.isEmpty) { _phoneError = null; return; }
      final clean = v.replaceAll(RegExp(r'[^0-9]'), '');
      _phoneError = clean.length < 9 ? 'Enter a valid phone number' : null;
    });
  }

  void _validatePassword(String v) {
    setState(() {
      if (v.isEmpty) { _passwordError = null; return; }
      _passwordError = v.length < 8 ? 'At least 8 characters required' : null;
      // re-check confirm
      if (_confirmCtrl.text.isNotEmpty) {
        _confirmError = _confirmCtrl.text != v ? 'Passwords do not match' : null;
      }
    });
  }

  void _validateConfirm(String v) {
    setState(() {
      if (v.isEmpty) { _confirmError = null; return; }
      _confirmError = v != _passwordCtrl.text ? 'Passwords do not match' : null;
    });
  }

  void _submit(BuildContext context) {
    final phone    = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    // Final sweep validation
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneErr    = phone.isEmpty ? 'Phone number required'
        : (clean.length < 9 ? 'Enter a valid phone number' : null);
    final passwordErr = password.isEmpty ? 'Password required'
        : (password.length < 8 ? 'At least 8 characters required' : null);
    final confirmErr  = confirm.isEmpty ? 'Please confirm password'
        : (confirm != password ? 'Passwords do not match' : null);

    setState(() {
      _phoneError    = phoneErr;
      _passwordError = passwordErr;
      _confirmError  = confirmErr;
    });

    if (phoneErr != null || passwordErr != null || confirmErr != null) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please confirm you are 18+ and agree to the Terms',
            style: _T.body(size: 13)),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ));
      return;
    }

    context.read<AuthCubit>().signUp(phone, password);
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
            content: Text(state.message, style: _T.body(size: 13)),
            backgroundColor: _C.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ));
        }
        if (state is AuthAuthenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _C.textMid, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildHero(),
                const SizedBox(height: 36),
                _buildForm(context),
                const SizedBox(height: 20),
                _buildTermsRow(),
                const SizedBox(height: 28),
                _buildSubmitButton(context),
                const SizedBox(height: 24),
                _buildLoginLink(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Gold icon badge
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: _C.goldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.goldBorder),
        ),
        child: const Icon(Icons.person_add_rounded, color: _C.gold, size: 26),
      ),
      const SizedBox(height: 20),
      Text(
        'Create Account',
        style: _T.mono.copyWith(
          fontSize: 28, fontWeight: FontWeight.bold,
          color: _C.textHigh, letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Join the Bingo Mekele community',
        style: _T.body(size: 14, color: _C.textLow),
      ),
    ]);
  }

  // ─── Form ─────────────────────────────────────────────────────────────────
  Widget _buildForm(BuildContext context) {
    return Column(children: [
      _SignupField(
        controller: _phoneCtrl,
        hint: 'Phone number (e.g. 0912…)',
        icon: Icons.phone_android_rounded,
        inputType: TextInputType.phone,
        errorText: _phoneError,
        onChanged: _validatePhone,
      ),
      const SizedBox(height: 14),
      _SignupField(
        controller: _passwordCtrl,
        hint: 'Password',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
        obscure: _obscurePassword,
        onToggleObscure: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        errorText: _passwordError,
        onChanged: _validatePassword,
      ),
      const SizedBox(height: 14),
      _SignupField(
        controller: _confirmCtrl,
        hint: 'Confirm password',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
        obscure: _obscureConfirm,
        onToggleObscure: () =>
            setState(() => _obscureConfirm = !_obscureConfirm),
        errorText: _confirmError,
        onChanged: _validateConfirm,
      ),
    ]);
  }

  // ─── Terms checkbox ────────────────────────────────────────────────────────
  Widget _buildTermsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Custom checkbox
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: _agreedToTerms ? _C.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _agreedToTerms ? _C.gold : _C.divider,
              width: 1.5,
            ),
          ),
          child: _agreedToTerms
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: _T.body(size: 13, color: _C.textMid),
              children: [
                const TextSpan(text: 'I confirm I am '),
                TextSpan(
                  text: '18 years or older',
                  style: _T.body(size: 13, weight: FontWeight.w700),
                ),
                const TextSpan(text: ' and agree to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _showTermsDialog,
                    child: Text(
                      'Terms of Service',
                      style: _T.body(
                        size: 13,
                        color: _C.accent,
                        weight: FontWeight.w600,
                      ).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: _C.accent,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Submit button ────────────────────────────────────────────────────────
  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _submit(context),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFF5CC50)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'CREATE ACCOUNT',
                style: _T.label(size: 14, color: Colors.black, spacing: 1.8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Login link ───────────────────────────────────────────────────────────
  Widget _buildLoginLink(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Already have an account? ', style: _T.body(size: 13, color: _C.textLow)),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Text('Sign In',
            style: _T.body(size: 13, color: _C.gold, weight: FontWeight.w600)),
      ),
    ]);
  }

  // ─── Terms dialog ─────────────────────────────────────────────────────────
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.cardHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.goldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gavel_rounded, color: _C.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Terms of Service', style: _T.body(size: 16, weight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Text(
            'By using Bingo Mekele you agree to the following:\n\n'
            '1. You must be at least 18 years old to play.\n\n'
            '2. This is a real-money game. Only deposit funds you can afford to lose.\n\n'
            '3. Winnings are subject to verification before payout.\n\n'
            '4. Fraudulent claims will result in account suspension.\n\n'
            '5. The operator reserves the right to cancel a session and refund stakes if a technical error occurs.\n\n'
            '6. Disputes are resolved at the sole discretion of the operator.',
            style: _T.body(size: 13, color: _C.textMid).copyWith(height: 1.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: _T.label(size: 12, color: _C.gold, spacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _SignupField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType inputType;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _SignupField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.inputType = TextInputType.text,
    this.isPassword = false,
    this.obscure = false,
    this.onToggleObscure,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return TextField(
      controller: controller,
      keyboardType: inputType,
      obscureText: isPassword && obscure,
      style: _T.body(size: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _T.body(size: 13, color: _C.textLow),
        prefixIcon: Icon(icon,
            color: hasError ? _C.danger : _C.gold, size: 19),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.textLow, size: 19,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        errorText: errorText,
        errorStyle: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            color: _C.danger,
            fontWeight: FontWeight.w500),
        filled: true,
        fillColor: _C.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? _C.danger.withOpacity(0.5) : _C.divider,
            width: 0.75,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: hasError ? _C.danger : _C.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 1.5),
        ),
      ),
    );
  }
}