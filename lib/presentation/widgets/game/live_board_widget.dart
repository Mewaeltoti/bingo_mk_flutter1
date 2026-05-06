import 'package:flutter/material.dart';

class LiveBoardWidget extends StatelessWidget {
  final List<int> drawnNumbers;

  const LiveBoardWidget({super.key, required this.drawnNumbers});

  Color _getColor(String letter) {
    switch (letter) {
      case "B": return const Color(0xFF3B82F6); // Blue
      case "I": return const Color(0xFFEF4444); // Red
      case "N": return const Color(0xFF10B981); // Green
      case "G": return const Color(0xFF8B5CF6); // Purple
      default: return const Color(0xFFF59E0B); // Orange
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? lastDrawn = drawnNumbers.isNotEmpty ? drawnNumbers.last : null;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header showing total count as in image
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              "Total Drawn: ${drawnNumbers.length}",
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 5 Rows for B-I-N-G-O
          ...List.generate(5, (row) {
            final letter = ["B", "I", "N", "G", "O"][row];
            final color = _getColor(letter);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  // Letter Badge
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 15 Number cells
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(15, (i) {
                        final num = row * 15 + i + 1;
                        final isDrawn = drawnNumbers.contains(num);
                        final isLast = num == lastDrawn;

                        return Expanded(
                          child: Container(
                            height: 22,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isLast 
                                  ? Colors.black 
                                  : (isDrawn ? color : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(4),
                              border: isLast ? Border.all(color: const Color(0xFF10B981), width: 2) : null,
                            ),
                            child: FittedBox(
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(
                                  "$num",
                                  style: TextStyle(
                                    color: isLast 
                                        ? const Color(0xFF10B981) 
                                        : (isDrawn ? Colors.white : const Color(0xFF64748B)),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
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
        ],
      ),
    );
  }
}
