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

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  String _pin = "";
  bool _phoneFocused = true;

  static const _bgColor = Color(0xFF0E1321);
  static const _cardBg = Color(0xFF141B2D);
  static const _inputBg = Color(0xFF090E1C);
  static const _goldPrimary = Color(0xFFF9C80E);
  static const _textPrimary = Color(0xFFDEE2F6);
  static const _textMuted = Color(0xFF8A94A6);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleKeyPress(String value) {
    if (_phoneFocused) {
      setState(() {
        if (value == "back") {
          if (_phoneController.text.isNotEmpty) {
            _phoneController.text =
                _phoneController.text.substring(0, _phoneController.text.length - 1);
          }
        } else {
          if (_phoneController.text.length < 10) {
            _phoneController.text += value;
          }
        }
      });
    } else {
      if (value == "back") {
        if (_pin.isNotEmpty) {
          setState(() => _pin = _pin.substring(0, _pin.length - 1));
        }
      } else {
        if (_pin.length < 4) {
          setState(() => _pin += value);
          if (_pin.length == 4) {
            _submitLogin();
          }
        }
      }
    }
  }

  void _submitLogin() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.enterValidPhone),
          backgroundColor: const Color(0xFF93000A),
        ),
      );
      setState(() => _phoneFocused = true);
      return;
    }
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("እባክዎ 4 ዲጂት ፒን ያስገቡ"),
          backgroundColor: Color(0xFF93000A),
        ),
      );
      return;
    }
    context.read<AuthCubit>().login(phone, _pin);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          LoadingDialog.show(context);
        } else {
          LoadingDialog.hide(context);
        }
        if (state is AuthError) {
          setState(() => _pin = ""); // reset PIN on error
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: const Color(0xFF93000A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
        if (state is AuthAuthenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Upper Header & Logo
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Minimalist Logo Text
                      const Text(
                        "ቢንጎ MK",
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 40,
                          color: _goldPrimary,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Interactive simple phone box
                      GestureDetector(
                        onTap: () => setState(() => _phoneFocused = true),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: _inputBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _phoneFocused ? _goldPrimary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android, color: _textMuted, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _phoneController.text.isEmpty
                                      ? "ስልክ ቁጥር ያስገቡ"
                                      : _phoneController.text,
                                  style: TextStyle(
                                    color: _phoneController.text.isEmpty
                                        ? _textMuted
                                        : _textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 4-Pin Dot Preview
                      const Text(
                        "የአገልግሎት ፒን (PIN) ያስገቡ",
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => setState(() => _phoneFocused = false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _pin.length;
                            final active = !_phoneFocused && index == _pin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? _goldPrimary : Colors.transparent,
                                border: Border.all(
                                  color: active ? _goldPrimary : _textMuted.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign up navigation
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
                        child: const Text(
                          "አዲስ አካውንት ለመክፈት ይጫኑ",
                          style: TextStyle(
                            color: _goldPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom custom PIN pad
              Container(
                color: _cardBg.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Column(
                  children: [
                    // Grid of numbers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ["1", "2", "3"].map((n) => _buildPadButton(n)).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ["4", "5", "6"].map((n) => _buildPadButton(n)).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ["7", "8", "9"].map((n) => _buildPadButton(n)).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Toggle focus button
                        _buildActionButton(
                          icon: _phoneFocused ? Icons.lock_outline : Icons.phone_android,
                          onTap: () {
                            setState(() => _phoneFocused = !_phoneFocused);
                          },
                        ),
                        _buildPadButton("0"),
                        // Backspace
                        _buildActionButton(
                          icon: Icons.backspace_outlined,
                          onTap: () => _handleKeyPress("back"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPadButton(String text) {
    return InkWell(
      onTap: () => _handleKeyPress(text),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 76,
        height: 56,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 76,
        height: 56,
        alignment: Alignment.center,
        child: Icon(icon, color: _textPrimary, size: 24),
      ),
    );
  }
}