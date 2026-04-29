import 'dart:math';
import '../../domain/entities/bingo_card.dart';

class BingoEngine {
  static const List<List<int>> _ranges = [
    [1, 15], // B
    [16, 30], // I
    [31, 45], // N
    [46, 60], // G
    [61, 75], // O
  ];

  static List<List<int>> generateCardNumbers() {
    final random = Random();
    final List<List<int>> columns = [];

    for (int col = 0; col < 5; col++) {
      final min = _ranges[col][0];
      final max = _ranges[col][1];
      final Set<int> columnNumbers = {};

      while (columnNumbers.length < 5) {
        columnNumbers.add(random.nextInt(max - min + 1) + min);
      }
      columns.add(columnNumbers.toList());
    }

    // Free space at center
    columns[2][2] = 0;

    // The TS logic returned columns as the outer list, which matches our 'columns' list.
    // In Flutter, we might want to represent it as rows for easier display,
    // but let's stick to the original logic structure for now.
    return columns;
  }

  static BingoCard generateCard({required String id, double price = 20.0}) {
    return BingoCard(id: id, numbers: generateCardNumbers(), price: price);
  }

  static List<BingoCard> generateCardSet(int count) {
    return List.generate(count, (i) => generateCard(id: 'cartela-${i + 1}'));
  }

  static bool checkWin(
    List<List<int>> grid,
    List<int> drawnNumbers,
    String pattern,
  ) {
    final drawnSet = Set<int>.from(drawnNumbers)
      ..add(0); // Center is always free (0)

    // Helper: check if a specific cell is drawn
    bool isDrawn(int r, int c) => drawnSet.contains(grid[r][c]);

    switch (pattern) {
      case 'Full House':
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            if (!isDrawn(r, c)) return false;
          }
        }
        return true;

      case 'Single Line H':
        for (int r = 0; r < 5; r++) {
          bool line = true;
          for (int c = 0; c < 5; c++) {
            if (!isDrawn(r, c)) {
              line = false;
              break;
            }
          }
          if (line) return true;
        }
        return false;

      case 'Single Line V':
        for (int c = 0; c < 5; c++) {
          bool line = true;
          for (int r = 0; r < 5; r++) {
            if (!isDrawn(r, c)) {
              line = false;
              break;
            }
          }
          if (line) return true;
        }
        return false;

      case 'X Shape':
        for (int i = 0; i < 5; i++) {
          if (!isDrawn(i, i)) return false;
          if (!isDrawn(i, 4 - i)) return false;
        }
        return true;

      case 'Four Corners':
        return isDrawn(0, 0) && isDrawn(0, 4) && isDrawn(4, 0) && isDrawn(4, 4);

      default:
        // Fallback to Full House for safety if pattern is unknown
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            if (!isDrawn(r, c)) return false;
          }
        }
        return true;
    }
  }

  static String getLetter(int number) {
    if (number >= 1 && number <= 15) return 'B';
    if (number >= 16 && number <= 30) return 'I';
    if (number >= 31 && number <= 45) return 'N';
    if (number >= 46 && number <= 60) return 'G';
    if (number >= 61 && number <= 75) return 'O';
    return '';
  }
}
