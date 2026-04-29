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
  final bool isUnregistered;
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
    this.isUnregistered = false,
    this.label,
    this.selected = false,
    this.lastDrawn,
  });

  @override
  Widget build(BuildContext context) {
    // Validate card.numbers is a 5x5 grid
    final bool validGrid = card.numbers.length == 5 && card.numbers.every((row) => row.length == 5);
    if (!validGrid) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Invalid Bingo Card: Expected 5x5 grid, got ${card.numbers.length} rows and row lengths: '
          '${card.numbers.map((r) => r.length).toList()}',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
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
                      color: Color(0xFF1976D2),
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

                  // Unregistered Status Bar
                  if (isUnregistered)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Unregistered',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  // Register Card Bar
                  if (onRegister != null && !isUnregistered)
                    Center(
                      child: GestureDetector(
                        onTap: onRegister,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Register Card',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),

                  // BINGO Claim Bar (Active Game)
                  if (onBingoClaim != null && !isBlocked)
                    Center(
                      child: GestureDetector(
                        onTap: onBingoClaim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784), // Light Green
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Bingo',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
      const Color(0xFF4CAF50), // B - Green
      const Color(0xFFF44336), // I - Red
      const Color(0xFF00BCD4), // N - Cyan
      const Color(0xFF2196F3), // G - Blue
      const Color(0xFFFF9800), // O - Orange
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        return Container(
          width: cellSize,
          height: cellSize * 0.6,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors[i],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            letters[i],
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: cellSize * 0.4,
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

            // 3 visual states:
            // 1. Free → Green
            // 2. Marked → Red with soft shadow
            // 3. Not marked → Plain white
            Color bgColor;
            Color borderColor;
            Color textColor;

            if (isFree) {
              bgColor = const Color(0xFF4CAF50);
              borderColor = const Color(0xFF388E3C);
              textColor = Colors.white;
            } else if (isMarked) {
              bgColor = const Color(0xFFFF5252);
              borderColor = const Color(0xFFE53935);
              textColor = Colors.white;
            } else {
              bgColor = Colors.white;
              borderColor = Colors.grey.shade300;
              textColor = Colors.black87;
            }

            return GestureDetector(
              onTap: () {
                if (!isFree && onMarkCell != null) {
                  onMarkCell!(row, col);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    if (isMarked && !isFree)
                      BoxShadow(
                        color: const Color(0xFFFF5252).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Text(
                  isFree ? 'F' : '$number',
                  style: TextStyle(
                    fontSize: cellSize * 0.38,
                    fontWeight: FontWeight.bold,
                    color: textColor,
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
