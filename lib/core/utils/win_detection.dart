import '../../domain/entities/bingo_card.dart';

class WinDetection {
  static bool checkWin({
    required List<List<int>> numbers,
    required Set<int> markedNumbers,
    required BingoPattern pattern,
  }) {
    bool isMarked(int row, int col) {
      if (row == 2 && col == 2) return true; // free space
      final num =
          numbers[col][row]; // Note: numbers[col][row] because of how it was generated
      return markedNumbers.contains(num);
    }

    switch (pattern) {
      case BingoPattern.fullHouse:
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            if (!isMarked(r, c)) return false;
          }
        }
        return true;

      case BingoPattern.singleLineH:
        for (int r = 0; r < 5; r++) {
          bool ok = true;
          for (int c = 0; c < 5; c++) {
            if (!isMarked(r, c)) {
              ok = false;
              break;
            }
          }
          if (ok) return true;
        }
        return false;

      case BingoPattern.singleLineV:
        for (int c = 0; c < 5; c++) {
          bool ok = true;
          for (int r = 0; r < 5; r++) {
            if (!isMarked(r, c)) {
              ok = false;
              break;
            }
          }
          if (ok) return true;
        }
        return false;

      case BingoPattern.singleLineD:
        bool d1 = true, d2 = true;
        for (int i = 0; i < 5; i++) {
          if (!isMarked(i, i)) d1 = false;
          if (!isMarked(i, 4 - i)) d2 = false;
        }
        return d1 || d2;

      case BingoPattern.twoLines:
        int lineCount = 0;
        // horizontal
        for (int r = 0; r < 5; r++) {
          bool ok = true;
          for (int c = 0; c < 5; c++) {
            if (!isMarked(r, c)) {
              ok = false;
              break;
            }
          }
          if (ok) lineCount++;
        }
        // vertical
        for (int c = 0; c < 5; c++) {
          bool ok = true;
          for (int r = 0; r < 5; r++) {
            if (!isMarked(r, c)) {
              ok = false;
              break;
            }
          }
          if (ok) lineCount++;
        }
        // diagonals
        bool d1 = true, d2 = true;
        for (int i = 0; i < 5; i++) {
          if (!isMarked(i, i)) d1 = false;
          if (!isMarked(i, 4 - i)) d2 = false;
        }
        if (d1) lineCount++;
        if (d2) lineCount++;
        return lineCount >= 2;

      case BingoPattern.fourCorners:
        return isMarked(0, 0) &&
            isMarked(0, 4) &&
            isMarked(4, 0) &&
            isMarked(4, 4);

      case BingoPattern.xShape:
        for (int i = 0; i < 5; i++) {
          if (!isMarked(i, i)) return false;
          if (!isMarked(i, 4 - i)) return false;
        }
        return true;

      case BingoPattern.tShape:
        for (int c = 0; c < 5; c++) {
          if (!isMarked(0, c)) return false;
        }
        for (int r = 0; r < 5; r++) {
          if (!isMarked(r, 2)) return false;
        }
        return true;

      case BingoPattern.lShape:
        for (int r = 0; r < 5; r++) {
          if (!isMarked(r, 0)) return false;
        }
        for (int c = 0; c < 5; c++) {
          if (!isMarked(4, c)) return false;
        }
        return true;

      case BingoPattern.cross:
        for (int c = 0; c < 5; c++) {
          if (!isMarked(2, c)) return false;
        }
        for (int r = 0; r < 5; r++) {
          if (!isMarked(r, 2)) return false;
        }
        return true;

      case BingoPattern.frame:
        for (int i = 0; i < 5; i++) {
          if (!isMarked(0, i)) return false;
          if (!isMarked(4, i)) return false;
          if (!isMarked(i, 0)) return false;
          if (!isMarked(i, 4)) return false;
        }
        return true;

      case BingoPattern.postageStamp:
        final corners = [
          [0, 0],
          [0, 3],
          [3, 0],
          [3, 3],
        ];
        for (final corner in corners) {
          int sr = corner[0];
          int sc = corner[1];
          if (isMarked(sr, sc) &&
              isMarked(sr, sc + 1) &&
              isMarked(sr + 1, sc) &&
              isMarked(sr + 1, sc + 1)) {
            return true;
          }
        }
        return false;

      case BingoPattern.smallDiamond:
        return isMarked(0, 2) &&
            isMarked(1, 1) &&
            isMarked(1, 3) &&
            isMarked(2, 0) &&
            isMarked(2, 4) &&
            isMarked(3, 1) &&
            isMarked(3, 3) &&
            isMarked(4, 2);

      case BingoPattern.arrowUp:
        for (int r = 0; r < 5; r++) {
          if (!isMarked(r, 2)) return false;
        }
        if (!isMarked(1, 1) || !isMarked(1, 3)) return false;
        if (!isMarked(0, 0) || !isMarked(0, 4)) return false;
        return true;

      case BingoPattern.pyramid:
        if (!isMarked(0, 2)) return false;
        if (!isMarked(1, 1) || !isMarked(1, 2) || !isMarked(1, 3)) return false;
        if (!isMarked(2, 0) ||
            !isMarked(2, 1) ||
            !isMarked(2, 2) ||
            !isMarked(2, 3) ||
            !isMarked(2, 4)) {
          return false;
        }
        return true;

      case BingoPattern.uShape:
        for (int r = 0; r < 5; r++) {
          if (!isMarked(r, 0)) return false;
        }
        for (int r = 0; r < 5; r++) {
          if (!isMarked(r, 4)) return false;
        }
        for (int c = 0; c < 5; c++) {
          if (!isMarked(4, c)) return false;
        }
        return true;
    }
  }

  static List<List<bool>> getPatternCells(BingoPattern pattern) {
    List<List<bool>> empty() => List.generate(5, (_) => List.filled(5, false));

    switch (pattern) {
      case BingoPattern.fullHouse:
        return List.generate(5, (_) => List.filled(5, true));
      case BingoPattern.singleLineH:
        final g = empty();
        for (int c = 0; c < 5; c++) {
          g[2][c] = true;
        }
        return g;
      case BingoPattern.singleLineV:
        final g = empty();
        for (int r = 0; r < 5; r++) {
          g[r][2] = true;
        }
        return g;
      case BingoPattern.singleLineD:
        final g = empty();
        for (int i = 0; i < 5; i++) {
          g[i][i] = true;
        }
        return g;
      case BingoPattern.twoLines:
        final g = empty();
        for (int c = 0; c < 5; c++) {
          g[1][c] = true;
          g[3][c] = true;
        }
        return g;
      case BingoPattern.fourCorners:
        final g = empty();
        g[0][0] = g[0][4] = g[4][0] = g[4][4] = true;
        return g;
      case BingoPattern.xShape:
        final g = empty();
        for (int i = 0; i < 5; i++) {
          g[i][i] = true;
          g[i][4 - i] = true;
        }
        return g;
      case BingoPattern.tShape:
        final g = empty();
        for (int c = 0; c < 5; c++) {
          g[0][c] = true;
        }
        for (int r = 0; r < 5; r++) {
          g[r][2] = true;
        }
        return g;
      case BingoPattern.lShape:
        final g = empty();
        for (int r = 0; r < 5; r++) {
          g[r][0] = true;
        }
        for (int c = 0; c < 5; c++) {
          g[4][c] = true;
        }
        return g;
      case BingoPattern.cross:
        final g = empty();
        for (int i = 0; i < 5; i++) {
          g[2][i] = true;
          g[i][2] = true;
        }
        return g;
      case BingoPattern.frame:
        final g = empty();
        for (int i = 0; i < 5; i++) {
          g[0][i] = g[4][i] = g[i][0] = g[i][4] = true;
        }
        return g;
      case BingoPattern.postageStamp:
        final g = empty();
        g[0][0] = g[0][1] = g[1][0] = g[1][1] = true;
        return g;
      case BingoPattern.smallDiamond:
        final g = empty();
        g[0][2] = g[1][1] = g[1][3] = g[2][0] = g[2][4] = g[3][1] = g[3][3] =
            g[4][2] = true;
        return g;
      case BingoPattern.arrowUp:
        final g = empty();
        for (int r = 0; r < 5; r++) {
          g[r][2] = true;
        }
        g[1][1] = g[1][3] = g[0][0] = g[0][4] = true;
        return g;
      case BingoPattern.pyramid:
        final g = empty();
        g[0][2] = true;
        g[1][1] = g[1][2] = g[1][3] = true;
        for (int c = 0; c < 5; c++) {
          g[2][c] = true;
        }
        return g;
      case BingoPattern.uShape:
        final g = empty();
        for (int r = 0; r < 5; r++) {
          g[r][0] = true;
          g[r][4] = true;
        }
        for (int c = 0; c < 5; c++) {
          g[4][c] = true;
        }
        return g;
    }
  }
}
