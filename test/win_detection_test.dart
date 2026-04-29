import 'package:flutter_test/flutter_test.dart';
import 'package:bingo_mk/core/utils/win_detection.dart';
import 'package:bingo_mk/domain/entities/bingo_card.dart';

void main() {
  group('WinDetection Tests', () {
    final List<List<int>> mockNumbers = [
      [1, 2, 3, 4, 5],    // B
      [16, 17, 18, 19, 20], // I
      [31, 32, 0, 34, 35],  // N (0 is free space)
      [46, 47, 48, 49, 50], // G
      [61, 62, 63, 64, 65], // O
    ];

    test('Full House should win when all numbers are marked', () {
      final Set<int> marked = {
        1, 2, 3, 4, 5,
        16, 17, 18, 19, 20,
        31, 32, 34, 35,
        46, 47, 48, 49, 50,
        61, 62, 63, 64, 65
      };

      final result = WinDetection.checkWin(
        numbers: mockNumbers,
        markedNumbers: marked,
        pattern: BingoPattern.fullHouse,
      );

      expect(result, isTrue);
    });

    test('Single Line H should win when a horizontal line is marked', () {
      // Row 0: 1, 16, 31, 46, 61
      final Set<int> marked = {1, 16, 31, 46, 61};

      final result = WinDetection.checkWin(
        numbers: mockNumbers,
        markedNumbers: marked,
        pattern: BingoPattern.singleLineH,
      );

      expect(result, isTrue);
    });

    test('Single Line V should win when a vertical line is marked', () {
      // Col 0: 1, 2, 3, 4, 5
      final Set<int> marked = {1, 2, 3, 4, 5};

      final result = WinDetection.checkWin(
        numbers: mockNumbers,
        markedNumbers: marked,
        pattern: BingoPattern.singleLineV,
      );

      expect(result, isTrue);
    });

    test('Four Corners should win when corners are marked', () {
      // Corners: (0,0)=1, (0,4)=61, (4,0)=5, (4,4)=65
      final Set<int> marked = {1, 61, 5, 65};

      final result = WinDetection.checkWin(
        numbers: mockNumbers,
        markedNumbers: marked,
        pattern: BingoPattern.fourCorners,
      );

      expect(result, isTrue);
    });
  });
}
