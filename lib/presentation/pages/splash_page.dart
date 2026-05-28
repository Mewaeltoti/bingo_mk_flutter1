import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashPage({super.key, required this.onFinish});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.0, 0.45, curve: Curves.easeIn)),
    );
    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack)),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.45, 0.85, curve: Curves.easeIn)),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                // Subtle decorative circle behind logo
                Positioned.fill(
                  child: Opacity(
                    opacity: _fadeAnim.value * 0.06,
                    child: Center(
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.secondary, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo badge
                      Opacity(
                        opacity: _fadeAnim.value,
                        child: Transform.scale(
                          scale: _scaleAnim.value,
                          child: _buildLogo(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Brand name
                      Opacity(
                        opacity: _fadeAnim.value,
                        child: Transform.scale(
                          scale: _scaleAnim.value,
                          child: const Text(
                            'AMBASSADOR',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondary,
                              letterSpacing: 6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: _fadeAnim.value,
                        child: Transform.scale(
                          scale: _scaleAnim.value,
                          child: const Text(
                            'BINGO',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Gold divider
                      Opacity(
                        opacity: _fadeAnim.value,
                        child: Container(
                          width: 60,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tagline
                      Opacity(
                        opacity: _taglineFade.value,
                        child: const Text(
                          'Play Smart. Win Big.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 56),
                      Opacity(
                        opacity: _taglineFade.value,
                        child: const AppSpinner(size: 36, strokeWidth: 2.5),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withOpacity(0.08),
        border: Border.all(
            color: AppColors.secondary.withOpacity(0.6), width: 2),
      ),
      child: Center(
        child: Text(
          'AB',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.secondary,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}