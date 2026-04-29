import 'package:flutter/material.dart';

class LiveBoardWidget extends StatelessWidget {
  final List<int> drawnNumbers;

  const LiveBoardWidget({
    super.key,
    required this.drawnNumbers,
  });

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
    final int? lastDrawn = drawnNumbers.isNotEmpty ? drawnNumbers.last : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // "Drawn: X" header
          Text(
            "Drawn: ${drawnNumbers.length}",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          
          // Grid
          Column(
            children: List.generate(5, (row) {
              final letter = ["B", "I", "N", "G", "O"][row];
              final color = _getColor(letter);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    // Letter box
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Numbers
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(15, (i) {
                          final num = row * 15 + i + 1;
                          final drawn = drawnNumbers.contains(num);
                          final isLastDrawn = num == lastDrawn;

                          Color bgColor;
                          Color textColor;
                          Color borderColor;

                          if (isLastDrawn) {
                            bgColor = Colors.black;
                            textColor = Colors.red;
                            borderColor = Colors.black;
                          } else if (drawn) {
                            bgColor = color;
                            textColor = Colors.white;
                            borderColor = color;
                          } else {
                            bgColor = Colors.grey.shade100;
                            textColor = Colors.black87;
                            borderColor = Colors.grey.shade300;
                          }

                          return Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  border: Border.all(color: borderColor, width: 1.0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "$num",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}