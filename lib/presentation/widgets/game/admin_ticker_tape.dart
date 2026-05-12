import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class AdminTickerTape extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;

  const AdminTickerTape({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFF1E293B),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 30,
      width: double.infinity,
      color: backgroundColor,
      child: Marquee(
        text: message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        blankSpace: 100.0,
        velocity: 50.0,
        pauseAfterRound: const Duration(seconds: 1),
        showFadingOnlyWhenScrolling: true,
        fadingEdgeStartFraction: 0.1,
        fadingEdgeEndFraction: 0.1,
        numberOfRounds: null,
        startPadding: 10.0,
        accelerationDuration: const Duration(seconds: 1),
        accelerationCurve: Curves.linear,
        decelerationDuration: const Duration(milliseconds: 500),
        decelerationCurve: Curves.easeOut,
      ),
    );
  }
}
