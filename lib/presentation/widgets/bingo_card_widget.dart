import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isWinner;

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
    this.isWinner = false,
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
          'Invalid Bingo Card: Expected 5x5 grid',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double cellSize = (availableWidth - (12 * 2) - (4 * 4)) / 5;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue Top Bar (As seen in image)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E88E5), // Material Blue
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tablet_android, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          card.cardNo.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (onRemove != null)
                          InkWell(
                            onTap: onRemove,
                            child: const Icon(Icons.close, size: 18, color: Colors.white),
                          ),
                      ],
                    ),
                  ),

                  // Optional status badge (Gray badge in image)
                  if (label != null || isUnregistered)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isUnregistered ? "UNREGISTERED" : label!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // Register/Bingo buttons
                  if (onRegister != null && !isUnregistered)
                    _buildActionButton("REGISTER", const Color(0xFF3B82F6), onRegister!),
                  
                  if (onBingoClaim != null && !isBlocked)
                    _buildActionButton("BINGO", const Color(0xFF10B981), onBingoClaim!),

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        _buildHeader(cellSize),
                        const SizedBox(height: 6),
                        _buildGrid(cellSize),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isBlocked) _buildOverlay("BLOCKED", Colors.black.withOpacity(0.7), Colors.red),
            if (isWinner) _buildOverlay("WON", Colors.green.withOpacity(0.4), Colors.green),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(String text, Color bgColor, Color labelColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: labelColor.withOpacity(0.5), blurRadius: 10)],
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ),
      ),
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
          height: cellSize * 0.7,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors[i],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            letters[i],
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
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
            final isMarked = isFree || markedCells.contains('$row-$col');

            Color bgColor = Colors.white;
            Color textColor = Colors.black87;
            Color borderColor = const Color(0xFFE2E8F0);

            if (isFree) {
              bgColor = const Color(0xFF10B981);
              textColor = Colors.white;
              borderColor = Colors.transparent;
            } else if (isMarked) {
              bgColor = const Color(0xFFEF4444); // Red circle for marked
              textColor = Colors.white;
              borderColor = Colors.transparent;
            }

            return GestureDetector(
              onTap: () {
                if (!isFree && onMarkCell != null) {
                  HapticFeedback.lightImpact();
                  onMarkCell!(row, col);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    if (isMarked && !isFree)
                      BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
                child: Text(
                  isFree ? 'F' : '$number',
                  style: TextStyle(
                    fontSize: cellSize * 0.4,
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
