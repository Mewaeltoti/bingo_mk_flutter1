import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class BallDrawOverlay extends StatelessWidget {
  final int number;
  final VoidCallback onFinish;

  const BallDrawOverlay({
    super.key,
    required this.number,
    required this.onFinish,
  });

  Color _getColor(int n) {
    if (n <= 15) return const Color(0xFF3B82F6);
    if (n <= 30) return const Color(0xFFEF4444);
    if (n <= 45) return const Color(0xFF10B981);
    if (n <= 60) return const Color(0xFF8B5CF6);
    return const Color(0xFFF59E0B);
  }

  String _getLetter(int n) {
    if (n <= 15) return "B";
    if (n <= 30) return "I";
    if (n <= 45) return "N";
    if (n <= 60) return "G";
    return "O";
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(number);
    final letter = _getLetter(number);

    return Center(
      child: ZoomIn(
        duration: const Duration(milliseconds: 500),
        child: FadeOut(
          delay: const Duration(seconds: 2),
          duration: const Duration(milliseconds: 500),
          onFinish: (_) => onFinish(),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
              border: Border.all(color: color, width: 8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  letter,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                Text(
                  "$number",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
