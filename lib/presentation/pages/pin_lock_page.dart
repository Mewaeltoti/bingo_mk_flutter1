import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../blocs/auth_cubit.dart';
import '../widgets/loading_dialog.dart';

class PinLockPage extends StatefulWidget {
  final String userId;
  final VoidCallback onVerified;

  const PinLockPage({
    super.key,
    required this.userId,
    required this.onVerified,
  });

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends State<PinLockPage> {
  String _pin = "";
  String _phone = "";

  static const _bgColor = Color(0xFF0E1321);
  static const _cardBg = Color(0xFF141B2D);
  static const _goldPrimary = Color(0xFFF9C80E);
  static const _textPrimary = Color(0xFFDEE2F6);
  static const _textMuted = Color(0xFF8A94A6);

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  void _loadPhoneNumber() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final emailParts = user.email!.split('@');
      if (emailParts.isNotEmpty) {
        setState(() {
          _phone = emailParts[0];
        });
      }
    }
  }

  bool _isLoading = false;

  void _handleKeyPress(String value) {
    if (_isLoading) return;
    if (value == "back") {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_pin.length < 4) {
        setState(() => _pin += value);
        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate by signing in again with the email and the salted PIN
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: user.email!,
          password: "${_pin}_bingo_secure_salt",
        );
        if (mounted) setState(() => _isLoading = false);
        widget.onVerified();
      } else {
        throw Exception("No active session");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pin = ""; // reset pin
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("የተሳሳተ ፒን ኮድ አስገብተዋል"),
          backgroundColor: Color(0xFF93000A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "ቢንጎ MK",
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 36,
                      color: _goldPrimary,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "እንኳን ደህና መጡ",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _phone,
                      style: const TextStyle(
                        color: _goldPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    "እባክዎ ፒን (PIN) ያስገቡ",
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_goldPrimary),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _pin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? _goldPrimary : Colors.transparent,
                                border: Border.all(
                                  color: _goldPrimary,
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () {
                      context.read<AuthCubit>().logout();
                    },
                    child: const Text(
                      "በሌላ አካውንት ለመግባት (ውጣ)",
                      style: TextStyle(
                        color: _goldPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: _cardBg.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                children: [
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
                      const SizedBox(width: 76),
                      _buildPadButton("0"),
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
