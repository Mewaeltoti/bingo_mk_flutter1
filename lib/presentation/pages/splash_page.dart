import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashPage({super.key, required this.onFinish});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  late AnimationController _barController;
  late Animation<double> _barProgress;

  static const _bgColor     = Color(0xFF050D1A);
  static const _goldPrimary = Color(0xFFD4AF37);
  static const _goldLight   = Color(0xFFFFE8AE);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoScale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _barProgress = CurvedAnimation(parent: _barController, curve: Curves.easeInOut);

    // Sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _barController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: _buildLogo(),
                ),
              ),
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: _barController,
              builder: (_, __) => _buildLoadingBar(_barProgress.value),
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value,
                child: _buildBrandTag(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandTag() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'POWERED BY',
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 7,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'TOTI TECH PLC',
          style: const TextStyle(
            color: _goldPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '+251 978 187 178',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.bingo,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 72,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            letterSpacing: 8,
            height: 1.0,
          ),
        ),
        const Text(
          S.mk,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 56,
            fontWeight: FontWeight.w400,
            color: _goldLight,
            letterSpacing: 18,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 32,
          height: 1.5,
          color: _goldPrimary.withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildLoadingBar(double progress) {
    return SizedBox(
      width: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 2,
              color: const Color(0xFF1C2E40),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  color: _goldPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress < 1.0 ? S.establishingSecurity : S.ready,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}