import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashPage({super.key, required this.onFinish});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // Logo animation
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  // Loading bar
  late AnimationController _barController;
  late Animation<double> _barProgress;

  // CTA fade in
  late AnimationController _ctaController;
  late Animation<double> _ctaFade;
  late Animation<Offset> _ctaSlide;

  // Particles
  final List<_Particle> _particles = [];
  late AnimationController _particleController;

  // Shimmer on MK text
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  static const _bgColor     = Color(0xFF0E1321);
  static const _cardBg      = Color(0xFF1A1F2E);
  static const _goldPrimary = Color(0xFFF9C80E);
  static const _goldLight   = Color(0xFFFFE8AE);
  static const _textMuted   = Color(0xFFD1C5AB);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Logo ──────────────────────────────────────────────────────────────
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoScale = Tween(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // ── Loading bar ───────────────────────────────────────────────────────
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _barProgress = CurvedAnimation(parent: _barController, curve: Curves.easeOut);

    // ── CTA ───────────────────────────────────────────────────────────────
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ctaFade  = CurvedAnimation(parent: _ctaController, curve: Curves.easeIn);
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctaController, curve: Curves.easeOut));

    // ── Shimmer on MK ─────────────────────────────────────────────────────
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(_shimmerController);

    // ── Particles ─────────────────────────────────────────────────────────
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    final rng = Random();
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x:        rng.nextDouble(),
        size:     rng.nextDouble() * 2.5 + 1,
        duration: rng.nextDouble() * 5 + 5,
        delay:    rng.nextDouble() * 5,
      ));
    }

    // ── Sequence ──────────────────────────────────────────────────────────
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _barController.forward();
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _ctaController.forward();
    });
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _barController.dispose();
    _ctaController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // ── Radial glow background ──────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _RadialGlowPainter()),
          ),

          // ── Floating particles ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) {
              return Stack(
                children: _particles.map((p) {
                  final t = (_particleController.value + p.delay / 10) % 1.0;
                  final progress = (t * (p.duration / 10)) % 1.0;
                  return Positioned(
                    left: p.x * size.width,
                    bottom: -10 + progress * (size.height + 20),
                    child: Opacity(
                      opacity: (progress < 0.1
                          ? progress / 0.1
                          : progress > 0.9
                              ? (1 - progress) / 0.1
                              : 1.0) *
                          0.6,
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: const BoxDecoration(
                          color: _goldPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
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

                // Loading bar + label
                AnimatedBuilder(
                  animation: _barController,
                  builder: (_, __) => _buildLoadingBar(_barProgress.value),
                ),

                const Spacer(flex: 2),

                // CTA button
                AnimatedBuilder(
                  animation: _ctaController,
                  builder: (_, __) => FadeTransition(
                    opacity: _ctaFade,
                    child: SlideTransition(
                      position: _ctaSlide,
                      child: _buildCta(),
                    ),
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: _goldLight, size: 14),
                const SizedBox(width: 6),
                Text(
                  'AUTHORIZED ACCESS ONLY',
                  style: TextStyle(
                    color: _textMuted.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // BINGO text
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (_, __) {
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end:   Alignment.centerRight,
                colors: const [
                  Color(0xFFDEE2F6),
                  Color(0xFFFFFFFF),
                  Color(0xFFDEE2F6),
                ],
                stops: [0.0, 0.5, 1.0],
                transform: _ShimmerTransform(_shimmerAnim.value),
              ).createShader(bounds),
              child: const Text(
                'BINGO',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 88,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 6,
                  height: 1.0,
                ),
              ),
            );
          },
        ),

        // MK text in gold
        const Text(
          'MK',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 72,
            fontWeight: FontWeight.w400,
            color: _goldLight,
            letterSpacing: 16,
            height: 1.0,
          ),
        ),

        const SizedBox(height: 12),

        // Gold divider
        Container(
          width: 48,
          height: 2,
          decoration: BoxDecoration(
            color: _goldPrimary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 4,
              color: const Color(0xFF303444),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: _goldPrimary,
                    boxShadow: [
                      BoxShadow(
                        color: _goldPrimary.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            progress < 1.0 ? 'ESTABLISHING SECURITY' : 'READY',
            style: TextStyle(
              color: _textMuted.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _goldPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _goldPrimary.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'ENTER LOUNGE',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D2F00),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Experience the height of professional bingo.',
            style: TextStyle(
              color: _textMuted.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Particle model ──────────────────────────────────────────────────────────
class _Particle {
  final double x;
  final double size;
  final double duration;
  final double delay;
  const _Particle({
    required this.x,
    required this.size,
    required this.duration,
    required this.delay,
  });
}

// ── Radial glow background painter ─────────────────────────────────────────
class _RadialGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Top center warm glow
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF1A1F2E).withOpacity(0.8),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width / 2, -size.height * 0.1),
      radius: size.width * 0.9,
    ));
    canvas.drawRect(Offset.zero & size, paint);

    // Subtle gold center glow
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFFF9C80E).withOpacity(0.04),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width / 2, size.height * 0.45),
      radius: size.width * 0.7,
    ));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Shimmer gradient transform ──────────────────────────────────────────────
class _ShimmerTransform extends GradientTransform {
  final double progress;
  const _ShimmerTransform(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * progress, 0, 0);
  }
}