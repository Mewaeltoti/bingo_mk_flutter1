import 'package:flutter/material.dart';
import '../../domain/entities/bingo_card.dart';

class BingoCardWidget extends StatelessWidget {
  final BingoCard card;
  final Set<int> drawnNumbers;
  final Set<String> markedCells;
  final Function(int row, int col)? onMarkCell;
  final VoidCallback? onRegister;
  final VoidCallback? onRemove;
  final VoidCallback? onBingoClaim;
  final bool isBlocked;
  final String? label;
  final bool selected;
  final int? lastDrawn;

  const BingoCardWidget({
    super.key,
    required this.card,
    this.drawnNumbers = const {},
    this.markedCells = const {},
    this.onMarkCell,
    this.onRegister,
    this.onRemove,
    this.onBingoClaim,
    this.isBlocked = false,
    this.label,
    this.selected = false,
    this.lastDrawn,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double cellSize = (availableWidth - (16 * 2) - (4 * 4)) / 5;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.credit_card,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          card.id
                              .replaceAll('P-', '')
                              .replaceAll('cartela-', ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (onRemove != null)
                          GestureDetector(
                            onTap: onRemove,
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Register Card Bar
                  if (onRegister != null)
                    GestureDetector(
                      onTap: onRegister,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF60A5FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Register Card',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  // BINGO Claim Bar (Active Game)
                  if (onBingoClaim != null && !isBlocked)
                    GestureDetector(
                      onTap: onBingoClaim,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.red],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BINGO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        _buildHeader(cellSize),
                        const SizedBox(height: 8),
                        _buildGrid(cellSize),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isBlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BLOCKED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(double cellSize) {
    const letters = ['B', 'I', 'N', 'G', 'O'];
    final colors = [
      const Color(0xFF10B981), // B - Green
      const Color(0xFFEF4444), // I - Red
      const Color(0xFF06B6D4), // N - Cyan
      const Color(0xFF3B82F6), // G - Blue
      const Color(0xFFF59E0B), // O - Orange
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        return Container(
          width: cellSize,
          height: cellSize * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors[i],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            letters[i],
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: cellSize * 0.45,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGrid(double cellSize) {
    return Column(
      children: List.generate(5, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (col) {
            final number = card.numbers[row][col];
            final isFree = row == 2 && col == 2;
            final cellKey = '$row-$col';
            final isMarked = isFree || markedCells.contains(cellKey);
            final isDrawn = drawnNumbers.contains(number);

            return GestureDetector(
              onTap: () {
                if (!isFree && isDrawn && onMarkCell != null) {
                  onMarkCell!(row, col);
                }
              },
              child: Container(
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFree
                      ? const Color(0xFF10B981)
                      : isMarked
                      ? const Color(0xFF10B981)
                      : Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    if (!isMarked && !isFree)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Text(
                  isFree ? 'F' : '$number',
                  style: TextStyle(
                    fontSize: cellSize * 0.4,
                    fontWeight: FontWeight.bold,
                    color: (isMarked || isFree) ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
