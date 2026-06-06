import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A premium animated spinner with a gradient stroke.
class AppSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const AppSpinner({
    super.key,
    this.size = 50,
    this.strokeWidth = 4,
    this.color,
  });

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.primaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _SpinnerPainter(
                color: primaryColor,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Background arc (faint)
    paint.color = color.withOpacity(0.1);
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);

    // Foreground gradient arc
    paint.shader = SweepGradient(
      colors: [color.withOpacity(0.0), color.withOpacity(0.5), color],
      stops: const [0.0, 0.5, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, 3 * math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A base skeleton widget with a shimmer effect.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const Skeleton({super.key, this.width, this.height, this.borderRadius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF0F1626),
                Color(0xFF1B243B),
                Color(0xFF0F1626),
              ],
              stops: [0.1, _animation.value.clamp(0.1, 0.9), 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// A layout-specific skeleton for the GamePage.
class GamePageSkeleton extends StatelessWidget {
  const GamePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Card Skeleton
          const Skeleton(height: 140, width: double.infinity, borderRadius: 12),
          const SizedBox(height: 20),

          // Recent Numbers / Toggle Skeleton
          const Center(child: Skeleton(height: 20, width: 100)),
          const SizedBox(height: 10),
          const Skeleton(height: 60, width: double.infinity, borderRadius: 12),
          const SizedBox(height: 20),

          // Grid Header
          const Skeleton(height: 24, width: 150),
          const SizedBox(height: 12),

          // Cards Grid Skeleton
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, _) => const Skeleton(borderRadius: 12),
          ),
        ],
      ),
    );
  }
}
