import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';

class LiveBoardWidget extends StatelessWidget {
  final List<int> drawnNumbers;

  const LiveBoardWidget({super.key, required this.drawnNumbers});

  Color _getColor(String letter) {
    switch (letter) {
      case "B": return AppColors.accent;
      case "I": return AppColors.danger;
      case "N": return AppColors.success;
      case "G": return const Color(0xFF8B5CF6);
      default: return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? lastDrawn = drawnNumbers.isNotEmpty ? drawnNumbers.last : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.numbers, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  "TOTAL DRAWN: ${drawnNumbers.length}",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),

          ...List.generate(5, (row) {
            final letter = ["B", "I", "N", "G", "O"][row];
            final color = _getColor(letter);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      border: Border.all(color: color, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(15, (i) {
                        final num = row * 15 + i + 1;
                        final isDrawn = drawnNumbers.contains(num);
                        final isLast = num == lastDrawn;

                        final cell = Container(
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isLast 
                                ? AppColors.secondary
                                : (isDrawn ? color.withOpacity(0.8) : Colors.white.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(6),
                            border: isLast ? Border.all(color: Colors.white, width: 1.5) : null,
                          ),
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: Text(
                                "$num",
                                style: TextStyle(
                                  color: isLast 
                                      ? Colors.black
                                      : (isDrawn ? Colors.white : Colors.white24),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        );

                        return Expanded(
                          child: isLast 
                              ? Pulse(infinite: true, duration: const Duration(seconds: 1), child: cell)
                              : cell,
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
