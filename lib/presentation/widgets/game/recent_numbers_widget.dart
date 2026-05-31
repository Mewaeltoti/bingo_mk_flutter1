import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class RecentNumbersWidget extends StatelessWidget {
  final List<int> numbers;
  const RecentNumbersWidget({super.key, required this.numbers});

  static String _letter(int n) {
    if (n <= 15) return 'B';
    if (n <= 30) return 'I';
    if (n <= 45) return 'N';
    if (n <= 60) return 'G';
    return 'O';
  }

  static Color _color(String l) {
    switch (l) {
      case 'B': return const Color(0xFF4FC3F7);
      case 'I': return const Color(0xFFE57373);
      case 'N': return const Color(0xFF81C784);
      case 'G': return const Color(0xFFBA68C8);
      default:  return const Color(0xFFF1C100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nums = numbers.reversed.toList();
    if (nums.isEmpty) {
      return Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF161B2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: const Text(
          'NO NUMBERS DRAWN YET',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF9A9078),
          ),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: nums.length,
        itemBuilder: (_, i) {
          final n = nums[i];
          final l = _letter(n);
          final c = _color(l);
          final isLatest = i == 0;

          return FadeInLeft(
            duration: Duration(milliseconds: isLatest ? 300 : 0),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 58,
              decoration: BoxDecoration(
                color: isLatest ? c.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLatest ? c : c.withOpacity(0.35),
                  width: isLatest ? 2 : 1,
                ),
                boxShadow: isLatest
                    ? [BoxShadow(color: c.withOpacity(0.4), blurRadius: 10)]
                    : [],
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: c,
                        letterSpacing: 0.5,
                      )),
                  Text('$n',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLatest ? c : c.withOpacity(0.7),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}