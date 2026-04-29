import 'package:flutter/material.dart';

class RecentNumbersWidget extends StatelessWidget {
  final List<int> numbers;

  const RecentNumbersWidget({
    super.key,
    required this.numbers,
  });

  String _getLetter(int n) {
    if (n <= 15) return "B";
    if (n <= 30) return "I";
    if (n <= 45) return "N";
    if (n <= 60) return "G";
    return "O";
  }

  Color _getColor(String letter) {
    switch (letter) {
      case "B":
        return Colors.blue;
      case "I":
        return Colors.red;
      case "N":
        return Colors.green;
      case "G":
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nums = numbers.reversed.toList();

    return SizedBox(
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: nums.length,
        itemBuilder: (_, i) {
          final n = nums[i];
          final letter = _getLetter(n);
          final color = _getColor(letter);

          return Container(
            margin: const EdgeInsets.only(right: 6),
            width: 55,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              "$letter\n$n",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}