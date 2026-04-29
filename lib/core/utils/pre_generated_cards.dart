import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../domain/entities/bingo_card.dart';

class PreGeneratedCards {
  static List<dynamic>? _cachedData;

  static Future<void> init() async {
    if (_cachedData != null) return;
    try {
      print('DEBUG: Loading assets/data.json...');
      final String response = await rootBundle.loadString('assets/data.json');
      _cachedData = json.decode(response);
      print('DEBUG: Successfully loaded ${_cachedData!.length} cards.');
    } catch (e) {
      print('ERROR: Failed to load pre-generated cards: $e');
      _cachedData = []; // Fallback to empty to prevent crashes
    }
  }

  static List<BingoCard> getRandomCards(int count) {
    if (_cachedData == null || _cachedData!.isEmpty) return [];

    final random = Random();
    final List<BingoCard> selected = [];
    final int total = _cachedData!.length;

    for (int i = 0; i < count; i++) {
      final index = random.nextInt(total);
      final data = _cachedData![index];
      final List<int> numbersList = List<int>.from(data['bingo_numbers']);
      
      // Convert flat list of 24 numbers to 5x5 grid with center free
      final List<List<int>> grid = List.generate(5, (_) => List.generate(5, (_) => 0));
      int listIdx = 0;
      for (int row = 0; row < 5; row++) {
        for (int col = 0; col < 5; col++) {
          if (row == 2 && col == 2) {
            grid[row][col] = 0; // Free space
          } else {
            grid[row][col] = numbersList[listIdx++];
          }
        }
      }

      selected.add(BingoCard(
        id: 'P-${data['cartela_no']}',
        numbers: grid,
        price: 10.0,
      ));
    }

    return selected;
  }
}
